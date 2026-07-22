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

SKILLS_DEST="$HOME/.agents/skills"
mkdir -p "$SKILLS_DEST"

for src in "$SCRIPT_DIR"/skills/*/; do
    [[ -d "$src" ]] || continue
    skill="$(basename "$src")"
    target="$SKILLS_DEST/$skill"
    if [[ -e "$target" || -L "$target" ]]; then
        echo "Warning: '$target' already exists. Skipping." >&2
        continue
    fi
    ln -s "${src%/}" "$target"
    echo "Linked $target -> ${src%/}"
for cfg in "${CONFIGS[@]}"; do
    ln -s "$SCRIPT_DIR/$cfg" "$DEST/$cfg"
    echo "Linked $DEST/$cfg -> $SCRIPT_DIR/$cfg"
done
