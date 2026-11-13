#!/usr/bin/env bash
#
# Two-way font sync with "AvalonLotus Mac - Font" in Google Drive for desktop:
# add the fonts in ~/Library/Fonts that the backup has under no name, then
# install the backup's fonts that this Mac has under no name.
#
# Run at login and every 30 minutes by the LaunchAgent com.avalonlotus.font-sync,
# which install.sh writes. Without the Drive folder it does nothing.
#
set -uo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# fontTools lives in a user site tied to one Python version; after a Homebrew
# upgrade the Command Line Tools Python may be the one that still has it.
for py in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
  if [ -x "$py" ] && "$py" -c 'import fontTools' 2>/dev/null; then
    exec "$py" "$SELF_DIR/font_sync.py"
  fi
done
echo "$(date '+%F %T') No python3 has fontTools installed; run install.sh again"
exit 1
