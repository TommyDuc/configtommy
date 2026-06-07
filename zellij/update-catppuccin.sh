#!/usr/bin/env bash
set -e

# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

curl -LO --output-dir $SCRIPT_DIR/themes https://raw.githubusercontent.com/catppuccin/zellij/refs/heads/main/catppuccin.kdl
