# reportools 仕様書

レポートプロジェクトの初期化と管理を行うコマンドラインツール。`reportools` は `rt` と省略できる。

## 1. 概要

- レポートの項目は、各プロジェクトのメタファイル `.reportools` に保存する。
- このマシンにあるレポートの場所は、パス一覧で管理する。データベースは使わない。
- リポジトリの作成と取得には `gh`、それ以外のリポジトリ操作には `git` を使う。
- 設定は ini 形式の config ファイルで行う。

## 2. 保存場所

| 場所 | 内容 | git 管理 |
|---|---|---|
| `$HOME/.config/reportools/config.ini` | ツールの設定 | 対象外 |
| `$HOME/.local/share/reportools/reports.tsv` | パス一覧 | 対象外 |
| `<project>/.reportools` | レポートの項目 | 対象 |

### 2.1 config.ini

```ini
[release]
title = 12345_氏名

[init]
style = typst

[github]
user = nagnagi
```

| キー | 意味 | 未設定時 |
|---|---|---|
| `release.title` | 提出用 PDF のファイル名。拡張子は付けない。 | `init` がエラー終了する |
| `init.style` | `init` の既定のスタイル | `typst` |
| `github.user` | リポジトリの所有者 | `gh api user` で取得する |

### 2.2 パス一覧

1行が1レポートで、`short` と絶対パスをタブで区切る。

```
algo1	/home/user/reports/algo1
```

### 2.3 メタファイル `.reportools`

```ini
[report]
short = algo1
title = アルゴリズム論 第1回レポート
subject = アルゴリズム論
deadline = 2026-11-30 23:59
state = draft
style = typst
```

## 3. 項目

| 項目 | オプション | 規則 |
|---|---|---|
| `short` | `-t`, `--short` | 唯一の識別子。英数字と `.` `_` `-` のみ。リポジトリ名にもなる。 |
| `title` | `-l`, `--title`, `--long` | レポートの正式な題名 |
| `subject` | `-j`, `--subj`, `--subject` | 科目名 |
| `deadline` | `-d`, `--in`, `--deadline` | `YYYY-MM-DD HH:MM`。時刻は必須。 |
| `state` | `-s`, `--state` | `draft` / `submit` / `resub` / `ok` |
| `path` | `-p`, `--path` | プロジェクトの絶対パス。パス一覧にだけ保存する。 |

`title`、`subject`、`deadline` は空でもよい。`state` は `init` の直後に `draft` になる。

## 4. コマンド

```
reportools <subcommand> [-<options>] [--<long option>, ...] <arguments>
```

`[short]` を省略すると、カレントディレクトリから上へ `.reportools` を探し、見つかったレポートを対象にする。

| コマンド | 動作 |
|---|---|
| `list [--<列>...]` | 締切の近い順に一覧を表示する。列を指定すると、その列だけをタブ区切りで見出しなしに出力する。 |
| `at [short] [--<列>...]` | 全項目を表示する。列を指定すると、その値だけを出力する。 |
| `get <short>` | `<user>/<short>` を `./<short>` に clone し、パス一覧に登録する。 |
| `sync [short]` / `sync --all` | `git pull` の後に `git push` を行う。commit はしない。 |
| `init <short> [--style <latex\|typst>] [--<列> <値>...]` | プロジェクトを初期化する(4.1)。 |
| `add [path] [--<列> <値>...]` | 既存のディレクトリをパス一覧に登録する。`.reportools` が無ければ作り、`--short` を省略するとディレクトリ名を `short` にする。 |
| `remove [short]` | パス一覧から外す。ディレクトリとリモートリポジトリは残す。 |
| `modify [short] --<列> <値>...` | 項目を更新する。commit はしない。 |
| `ok [short]` | レポートを完了にする。`modify [short] --state ok` と同じ。 |
| `export` | 全レポートの全項目を、見出し付きの TSV で標準出力に出す。 |
| `config <key> [value]` / `config --list` | 設定を取得、設定、一覧表示する。 |

`modify` では `short` を変更できない。`--path` はパス一覧だけを更新する。

### 4.1 init

1. `release.title` が未設定なら、設定方法を表示してエラー終了する。この時点では何も作らない。
2. `./<short>` を作り、5章の構成を生成する。
3. `git init`、全ファイルの commit を行い、パス一覧に登録する。
4. `gh` で `<user>/<short>` を private で作り、push する。

### 4.2 共通オプション

| オプション | 動作 |
|---|---|
| `--help` | usage を表示する。サブコマンドの後に置くと、そのサブコマンドの usage を表示する。 |
| `--version` | version を表示する。 |
| `--env <zsh\|bash>` | シェルの設定を出力する。`eval "$(reportools --env zsh)"` として使う。 |

`--env zsh` は `rt` のエイリアスと補完関数を、`--env bash` はエイリアスだけを出力する。

## 5. レポートプロジェクトの形式

```
<short>/
├── .gitignore
├── .reportools
├── Makefile                 (typst のみ)
├── complete/                提出用に製本した版
├── reference/               配布された資料
└── src/
    ├── main.typ             (latex では main.tex)
    ├── main.bib
    └── resource/
        ├── code/            レポートで参照するプログラム
        ├── img/             画像
        └── title/           タイトル用のファイル(任意)
```

- 空のディレクトリには `.gitkeep` を置く。
- `.version/` と `complete/` のサブディレクトリは Makefile が生成する。`init` では作らない。
- `--style latex` は同じ構成を作るが、Makefile は生成しない。

### 5.1 Makefile

`TITLE` は `release.title` に `.pdf` を付けた値にする。それ以外は固定の内容である(`src/templates/typst/Makefile`)。

### 5.2 .gitignore

```
main.pdf
complete/<release.title>.pdf
```

## 6. 技術要件

- Zig で実装する。外部ライブラリは使わない。
- `git` と `gh` は子プロセスとして呼び出す。
- zsh の補完、man、`install.sh` を用意する。`install.sh` は `$HOME/.local` の下にインストールする。
