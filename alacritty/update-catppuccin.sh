#!/usr/bin/env bash
set -e
# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

curl -LO --output-dir "$SCRIPT_DIR/themes" https://github.com/catppuccin/alacritty/raw/main/catppuccin-latte.toml
curl -LO --output-dir "$SCRIPT_DIR/themes" https://github.com/catppuccin/alacritty/raw/main/catppuccin-frappe.toml
curl -LO --output-dir "$SCRIPT_DIR/themes" https://github.com/catppuccin/alacritty/raw/main/catppuccin-macchiato.toml
curl -LO --output-dir "$SCRIPT_DIR/themes" https://github.com/catppuccin/alacritty/raw/main/catppuccin-mocha.toml
