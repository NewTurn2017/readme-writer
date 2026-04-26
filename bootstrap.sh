#!/usr/bin/env bash
# readme-writer bootstrap installer for macOS / Linux.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/NewTurn2017/readme-writer/main/bootstrap.sh | bash
#
# Env vars:
#   READMEW_HOME    Install destination. Default: $HOME/.readme-writer
#   READMEW_REPO    Git URL. Default: https://github.com/NewTurn2017/readme-writer.git
#   READMEW_REF     Git ref. Default: main

set -eo pipefail

REPO_URL="${READMEW_REPO:-https://github.com/NewTurn2017/readme-writer.git}"
REF="${READMEW_REF:-main}"
DEST="${READMEW_HOME:-$HOME/.readme-writer}"
INSTALL_ARGS=("$@")

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue()  { printf '\033[34m%s\033[0m\n' "$*"; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    red "missing required command: $1"; exit 1
  fi
}

case "$(uname -s)" in
  Darwin|Linux) ;;
  MINGW*|MSYS*|CYGWIN*)
    red "Detected Windows shell. Please use the PowerShell installer instead:"
    echo "  iwr -useb https://raw.githubusercontent.com/NewTurn2017/readme-writer/main/bootstrap.ps1 | iex"
    exit 1 ;;
  *) red "unsupported OS: $(uname -s)"; exit 1 ;;
esac

require git
require bash
require python3

blue "[1/3] cloning $REPO_URL → $DEST"
if [ -d "$DEST/.git" ]; then
  git -C "$DEST" fetch --quiet origin "$REF"
  git -C "$DEST" checkout --quiet "$REF"
  git -C "$DEST" pull --quiet --ff-only origin "$REF" || true
  green "  updated existing checkout."
else
  if [ -e "$DEST" ] && [ ! -d "$DEST" ]; then
    red "  $DEST exists and is not a directory. aborting."; exit 1
  fi
  if [ -d "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
    red "  $DEST is non-empty and not a git repo. aborting."; exit 1
  fi
  git clone --quiet --branch "$REF" "$REPO_URL" "$DEST"
  green "  cloned."
fi

blue "[2/3] running install.sh ${INSTALL_ARGS[*]:-(no args)}"
cd "$DEST"
chmod +x install.sh
./install.sh "${INSTALL_ARGS[@]}"

blue "[3/3] done."
green "✓ readme-writer installed at $DEST"
echo
echo "Next steps:"
echo "  - Start a new Claude Code or Codex session in any repo."
echo "  - Try: '이 레포에 README 써줘' or 'write README for this project'"
echo "  - Update later: cd \"$DEST\" && git pull"
