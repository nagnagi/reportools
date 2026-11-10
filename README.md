<h1 align="center">
  <img src="assets/logo.svg" width="420" alt="reportools">
</h1>

<p align="center">
  A command-line tool that scaffolds report projects and tracks their deadlines and submission states
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Zig-0.17.1%2B-f7a41d?logo=zig&logoColor=white" alt="Zig 0.17.1+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License">
</p>

```console
$ rt list
SHORT  SUBJECT            DEADLINE          STATE   TITLE
os3    Operating Systems  2026-11-20 12:00  ok      Comparing schedulers
algo1  Algorithms         2026-11-30 23:59  draft   Report 1: Sorting
net2   Networks           2026-12-05 17:00  submit  TCP congestion control
```

## Installation

You need Zig 0.17.1 or later, `git`, and [`gh`](https://cli.github.com/).

```sh
git clone https://github.com/nagnagi/reportools.git
cd reportools
./install.sh
```

`install.sh` installs under `~/.local`. To install somewhere else, set `PREFIX`.

```sh
PREFIX="$HOME/opt" ./install.sh
```

To enable the `rt` alias and zsh completion, add the following line to `~/.zshrc`, after `compinit`. For bash, add the line to `~/.bashrc` and use `--env bash`. Bash gets the alias only.

```sh
eval "$(reportools --env zsh)"
```

## Features

- `rt init` creates a Typst or LaTeX template, a git repository, and a private GitHub repository in one step.
- `rt list` shows every report, soonest deadline first.
- Each report has one of four states: `draft`, `submit`, `resub`, or `ok`.
- The details of a report live in a `.reportools` file inside the project. Git tracks that file, so on another machine `rt get` clones the report and adds it to the list.
- `rt list --short --deadline` and `rt export` print tab-separated values that shell scripts can read.
- reportools is written in Zig with no external libraries, and it uses no database.

## Usage

First, set the file name of the PDFs that you submit.

```sh
rt config release.title 12345_YourName
```

Then create a report, write it, and submit it.

```sh
rt init algo1 -j Algorithms -d "2026-11-30 23:59"
cd algo1
make release              # builds complete/12345_YourName.pdf
rt modify --state submit  # mark the report as submitted
rt ok                     # mark the report as finished
```

Inside a report directory, you can omit `short`.

### Commands

| Command | Action |
|---|---|
| `rt init <short>` | Create a project and its private repository |
| `rt list` | Show every report, soonest deadline first |
| `rt at [short]` | Show the details of one report |
| `rt modify [short] --<column> <value>` | Update the details or state of a report |
| `rt ok [short]` | Mark a report as finished |
| `rt get <short>` | Clone an existing report repository and register it |
| `rt add [path]` | Register an existing directory |
| `rt remove [short]` | Forget a report. Its files and repository are kept |
| `rt sync [short]`, `rt sync --all` | Run `git pull`, then `git push` |
| `rt export` | Print every report as TSV |
| `rt config <key> [value]` | Read or change a setting |

For the options of each command, run `rt <command> --help` or `man reportools`. The [specification](docs/spec.md) (in Japanese) describes the file formats and every setting.

## License

[MIT License](LICENSE)

## Contributing

Issues and pull requests are welcome. Before you open a pull request, make sure that the tests pass.

```sh
zig build test
```

If you change behavior, update the [specification](docs/spec.md) and `man/reportools.1` too.
