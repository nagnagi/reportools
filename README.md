# reportools

レポートプロジェクトの初期化と管理を行うコマンドラインツール。`rt` と省略できる。

仕様は [docs/spec.md](docs/spec.md)、使い方の詳細は `man reportools` を参照。

## インストール

Zig 0.17.1 以降、`git`、`gh` が必要。

```sh
./install.sh
```

`~/.local` の下にインストールされる。インストール先は `PREFIX` で変更できる。

`~/.zshrc` の `compinit` より後(bash の場合は `~/.bashrc`)に次の行を追加すると、`rt` のエイリアスと zsh の補完が有効になる。

```sh
eval "$(reportools --env zsh)"   # bash の場合は --env bash
```

## 使い方

```sh
rt config release.title 12345_氏名          # 提出用 PDF のファイル名(初回のみ)

rt init algo1 -j アルゴリズム論 -d "2026-11-30 23:59"
cd algo1
make release                                # complete/12345_氏名.pdf を作る
rt modify --state submit
rt list
```

## 開発

```sh
zig build test
```
