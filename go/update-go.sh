#!/usr/bin/env bash
# Update the Go toolchain installed in /usr/local/go from the official tarballs.
set -euo pipefail

INSTALL_DIR="/usr/local"
GO_BIN="$INSTALL_DIR/go/bin/go"

usage() {
    cat <<EOF
Usage: $(basename "$0") [VERSION]

Install Go into $INSTALL_DIR/go from https://go.dev/dl.

  VERSION   Optional, e.g. 1.27.1 or go1.27.1. Defaults to the latest stable.
  -h        Show this help.
EOF
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

for cmd in curl tar sha256sum sudo; do
    command -v "$cmd" >/dev/null || { echo "Error: '$cmd' is required." >&2; exit 1; }
done

# Resolve version.
if [[ -n "${1:-}" ]]; then
    VER="$1"
    [[ "$VER" == go* ]] || VER="go$VER"
else
    VER="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
fi

# Detect platform.
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Error: unsupported architecture '$(uname -m)'." >&2; exit 1 ;;
esac

TARBALL="$VER.$OS-$ARCH.tar.gz"

# Skip if already installed.
CURRENT=""
if [[ -x "$GO_BIN" ]]; then
    CURRENT="$("$GO_BIN" version | awk '{print $3}')"
fi
if [[ "$CURRENT" == "$VER" ]]; then
    echo "Go is already up to date ($VER)."
    exit 0
fi

# Look up the expected checksum.
get_sha() {
    curl -fsSL "$1" | grep -A4 "\"filename\": \"$TARBALL\"" \
        | sed -n 's/.*"sha256": "\([0-9a-f]\{64\}\)".*/\1/p' | head -n1 || true
}
SHA="$(get_sha 'https://go.dev/dl/?mode=json')"
[[ -n "$SHA" ]] || SHA="$(get_sha 'https://go.dev/dl/?mode=json&include=all')"
if [[ -z "$SHA" ]]; then
    echo "Error: no release found for '$TARBALL'." >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $TARBALL..."
curl -fL --progress-bar -o "$TMP/$TARBALL" "https://go.dev/dl/$TARBALL"

echo "Verifying checksum..."
(cd "$TMP" && echo "$SHA  $TARBALL" | sha256sum -c --quiet -)

echo "Installing ${CURRENT:-none} -> $VER in $INSTALL_DIR/go (sudo required)..."
sudo rm -rf "$INSTALL_DIR/go"
sudo tar -C "$INSTALL_DIR" -xzf "$TMP/$TARBALL"

"$GO_BIN" version
if [[ "$(command -v go || true)" != "$GO_BIN" ]]; then
    echo "Warning: '$INSTALL_DIR/go/bin' is not first on PATH (go resolves to '$(command -v go || echo none)')." >&2
fi
