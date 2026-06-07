#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Hardcoded list of config folders to symlink.
# Update this if new folder are added.
CONFIGS=(
    alacritty
    atuin
    lazygit
    nvim
    zellij
)

DEST="${1:-$HOME/.config}"

if [[ -n "${1:-}" && ! -d "$DEST" ]]; then
    echo "Error: '$DEST' is not a valid directory." >&2
    exit 1
fi

for cfg in "${CONFIGS[@]}"; do
    src="$SCRIPT_DIR/$cfg"
    if [[ ! -d "$src" ]]; then
        echo "Error: source folder '$src' not found in repo. Aborting." >&2
        exit 1
    fi
done

for cfg in "${CONFIGS[@]}"; do
    target="$DEST/$cfg"
    if [[ -e "$target" || -L "$target" ]]; then
        echo "Error: '$target' already exists. Aborting." >&2
        exit 1
    fi
done

for cfg in "${CONFIGS[@]}"; do
    ln -s "$SCRIPT_DIR/$cfg" "$DEST/$cfg"
    echo "Linked $DEST/$cfg -> $SCRIPT_DIR/$cfg"
done
