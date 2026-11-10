#!/bin/sh
# Builds reportools and installs the binary and man pages under $PREFIX (default: ~/.local).
set -eu

PREFIX="${PREFIX:-$HOME/.local}"

cd "$(dirname "$0")"

for tool in zig git gh; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "install.sh: $tool is required but was not found" >&2
        exit 1
    fi
done

zig build --release=safe --prefix "$PREFIX"

cat <<EOF
Installed:
  $PREFIX/bin/reportools
  $PREFIX/share/man/man1/reportools.1

Next steps:
  1. Make sure $PREFIX/bin is in PATH.
  2. Add this line to ~/.zshrc (after compinit) or ~/.bashrc:
       eval "\$(reportools --env zsh)"     # or: --env bash
  3. Set the file name of released PDFs:
       reportools config release.title <name>
EOF
