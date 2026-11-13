#!/usr/bin/env bash
#
# One-line install on a Mac:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AvalonLotus/AvalonLotus-Setup-Install/main/Mac/bootstrap.sh)"
#
# install.sh needs the settings/ folder beside it, so it cannot be piped from
# curl on its own. This script downloads the whole repo with curl and tar (both
# ship with macOS, so no git is needed yet), then runs install.sh, which copies
# the Mac folder to ~/.local/share/avalonlotus-mac-setup before anything else.
#
set -euo pipefail

REPO="AvalonLotus/AvalonLotus-Setup-Install"
BRANCH="main"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading $REPO ($BRANCH)"
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$WORK"

INSTALL="$WORK/${REPO#*/}-$BRANCH/Mac/install.sh"
[ -f "$INSTALL" ] || { echo "install.sh not found in the download"; exit 1; }
bash "$INSTALL"
