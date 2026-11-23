#!/usr/bin/env bash
#
# AvalonLotus Mac setup
# Usage: in Terminal on the Mac, run  bash "<this folder>/install.sh"
# Safe to run again: anything already installed is skipped.
#
set -uo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
# Hidden, so the copy does not show up as a second setup folder in Finder.
HOME_DIR="$HOME/.local/share/avalonlotus-mac-setup"
FAILS=()

log()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; FAILS+=("$1"); }

# ─── 0. Copy this folder to the fixed hidden location (font sync and transcribe run from there)
log "Copying the setup folder to $HOME_DIR"
if [ "$SRC_DIR" != "$HOME_DIR" ]; then
  # Replace the copy as a whole, so files removed from the repo do not linger.
  rm -rf "$HOME_DIR"
  mkdir -p "$HOME_DIR"
  cp -R "$SRC_DIR/." "$HOME_DIR/"
fi
# Earlier versions copied it to ~/Mac-Setup; remove that copy when it is ours.
if [ -f "$HOME/Mac-Setup/install.sh" ] && [ -d "$HOME/Mac-Setup/settings" ]; then rm -rf "$HOME/Mac-Setup"; fi
ok "$HOME_DIR"

# ─── 1. Homebrew
log "Homebrew"
sudo -v || true
# sudo forgets the password after about 5 minutes, and the installs below take
# much longer, so refresh it in the background until this script ends: the
# password is asked once instead of again for every app that needs it.
( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

# Once Xcode is in /Applications, git, brew and /usr/bin/python3 stop with
# "You have not agreed to the Xcode license" until its license is accepted.
# Run at the start (Xcode from an earlier run) and after the App Store step
# (Xcode installed by this run), while sudo is active, so nothing is typed.
accept_xcode() {
  [ -d /Applications/Xcode.app ] || return 0
  if ! /usr/bin/xcodebuild -license check >/dev/null 2>&1; then
    sudo /usr/bin/xcodebuild -license accept >/dev/null 2>&1 && ok "Xcode license accepted" || warn "Xcode license not accepted"
  fi
  if ! /usr/bin/xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    sudo /usr/bin/xcodebuild -runFirstLaunch >/dev/null 2>&1 && ok "Xcode components" || warn "Xcode components failed to install"
  fi
}
accept_xcode

if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo "Homebrew installation failed"; exit 1; }
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
# Each brew command clears the sudo password before its first sudo step
# (utils/sudo.sh runs `sudo --reset-timestamp` unless HOMEBREW_SUDO_CHECKED=1),
# so every app that needs sudo asked again. The password was already checked
# above, so tell brew the check is done. A newly installed Homebrew may have
# cleared it too, so ask once more only in that case.
sudo -n true 2>/dev/null || sudo -v || true
export HOMEBREW_SUDO_CHECKED=1
export HOMEBREW_NO_EMOJI=1
export HOMEBREW_NO_ENV_HINTS=1
# Newer Homebrew asks "Do you want to proceed with the installation? [y/n]"
# before installing anything with dependencies; install without asking.
export HOMEBREW_NO_ASK=1
export HOMEBREW_CURLRC="$HOME_DIR/settings/homebrew-curlrc"
ok "brew $(brew --version | head -1)"

# ─── 2. Command-line tools (23)
FORMULAE="gh node python python@3.14 rust yt-dlp ffmpeg tesseract tesseract-lang pandoc poppler whisper-cpp opencc git-lfs xcodegen mas cloudflared ollama powershell rclone ripgrep opencode sevenzip coreutils"
log "Command-line tools"
for f in $FORMULAE; do
  if brew list --formula "$f" >/dev/null 2>&1; then ok "$f already installed"
  else brew install "$f" && ok "$f" || warn "$f failed to install"; fi
done

# ─── 3. Apps (17)
# cask|app in /Applications; an app installed another way (downloaded, App
# Store) is skipped instead of reinstalled. Casks without an app name are
# checked through brew only.
CASKS="docker|Docker
google-chrome|Google Chrome
discord|Discord
telegram|Telegram
claude|Claude
claude-code|
chatgpt|ChatGPT
codex|
grok-bot|Grok Bot
visual-studio-code|Visual Studio Code
rectangle|Rectangle
appcleaner|AppCleaner
iina|IINA
obs|OBS
obsidian|Obsidian
libreoffice|LibreOffice
google-drive|Google Drive"
log "Apps"
while IFS='|' read -r c app; do
  [ -z "$c" ] && continue
  if brew list --cask "$c" >/dev/null 2>&1; then ok "$c already installed"
  elif [ -n "$app" ] && [ -d "/Applications/$app.app" ]; then ok "$c already installed (outside Homebrew)"
  else brew install --cask "$c" && ok "$c" || warn "$c failed to install"; fi
done <<< "$CASKS"

# ─── 4. App Store apps (10; requires being signed in to the App Store)
MAS_APPS="497799835|Xcode
539883307|LINE
310633997|WhatsApp
517914548|Dashlane
1437809329|Surfshark
361285480|Keynote
361304891|Numbers
361309726|Pages
682658836|GarageBand
408981434|iMovie"
log "App Store apps"
INSTALLED_MAS="$(mas list 2>/dev/null | awk '{print $1}' || true)"
while IFS='|' read -r id name; do
  [ -z "$id" ] && continue
  if printf '%s\n' "$INSTALLED_MAS" | grep -qx "$id"; then ok "$name already installed"
  else mas install "$id" && ok "$name" || warn "$name failed to install (check that you are signed in to the App Store)"; fi
done <<< "$MAS_APPS"

# Xcode may have been installed just now; accept its license before the steps below.
accept_xcode

# ─── 5. Python packages
log "Python packages"
# Homebrew's newest python3 can be ahead of what the pinned packages support
# (markitdown and docling require Python below 3.15), so they go into 3.14;
# settings/home/.zprofile makes python3 and pip3 in Terminal mean 3.14.
/opt/homebrew/bin/python3.14 -m pip install --user --break-system-packages --no-warn-script-location --disable-pip-version-check -q -r "$HOME_DIR/settings/requirements-user.txt" \
  && ok "Python 3.14 packages" || warn "Python 3.14 packages failed to install"
/usr/bin/python3 -m pip install --user --no-warn-script-location --disable-pip-version-check -q -r "$HOME_DIR/settings/requirements-system-python.txt" \
  && ok "System Python packages" || warn "System Python packages failed to install"
/usr/bin/python3 -m playwright install chromium >/dev/null 2>&1 && ok "Playwright browser" || warn "Playwright browser failed to install"

# ─── 6. transcribe (local speech-to-text for recordings)
log "transcribe"
WHISPER_DIR="$HOME/.cache/whisper-models"
WHISPER_MODEL="$WHISPER_DIR/ggml-large-v3.bin"
WHISPER_BYTES=3095033483
mkdir -p "$WHISPER_DIR"
if [ "$(stat -f %z "$WHISPER_MODEL" 2>/dev/null || echo 0)" = "$WHISPER_BYTES" ]; then ok "Speech model already downloaded"
else
  curl -fL -C - --retry 3 -o "$WHISPER_MODEL" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin" \
    && ok "Speech model downloaded" || warn "Speech model download incomplete; run this script again to resume it"
fi
chmod +x "$HOME_DIR/transcribe.sh"
ln -sf "$HOME_DIR/transcribe.sh" "$(brew --prefix)/bin/transcribe" && ok "transcribe command"

# ─── 7. Font sync (at login and every 30 minutes)
log "Font sync"
FONT_PLIST="$HOME/Library/LaunchAgents/com.avalonlotus.font-sync.plist"
FONT_LOG_DIR="$HOME/.local/state/font-sync"
mkdir -p "$FONT_LOG_DIR" "$HOME/Library/LaunchAgents"
cat > "$FONT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.avalonlotus.font-sync</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>$HOME_DIR/settings/fonts-sync.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>1800</integer>
  <key>StandardOutPath</key><string>$FONT_LOG_DIR/font-sync.log</string>
  <key>StandardErrorPath</key><string>$FONT_LOG_DIR/font-sync.log</string>
</dict></plist>
PLIST
launchctl bootout "gui/$(id -u)" "$FONT_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$FONT_PLIST" 2>/dev/null && ok "Font sync started" || warn "Font sync will start at the next login"

# ─── 8. Mac settings (4)
log "Mac settings"
# Click the wallpaper to show the desktop
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool true
# Hot corners: bottom left / bottom right
defaults write com.apple.dock wvous-bl-corner -int 5
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 1
defaults write com.apple.dock wvous-br-modifier -int 1048576
# Screen saver delay (seconds)
defaults -currentHost write com.apple.screensaver idleTime -int 120
killall Dock 2>/dev/null || true
ok "Click wallpaper to show desktop, hot corners, screen saver"
# Terminal settings (the old file is backed up first)
# Only the first run keeps a backup, so repeated runs leave one ~/.zprofile.bak, not a pile.
if [ -f "$HOME/.zprofile" ] && [ ! -e "$HOME/.zprofile.bak" ] && ! cmp -s "$HOME/.zprofile" "$HOME_DIR/settings/home/.zprofile"; then cp "$HOME/.zprofile" "$HOME/.zprofile.bak"; fi
cp "$HOME_DIR/settings/home/.zprofile" "$HOME/.zprofile"
ok "Terminal settings"
# Git identity
git config --global user.name  "AvalonLotus"
git config --global user.email "Lien.Founder@AvalonLotus.com"
git config --global credential.helper osxkeychain
git lfs install >/dev/null 2>&1 || true
ok "Git identity"

# ─── 9. Claude Code plugins (1)
# Modern Web Guidance points coding agents at current web platform practices.
# Its telemetry is off through DISABLE_TELEMETRY in settings/home/.zprofile.
log "Claude Code plugins"
MWG_PLUGIN="modern-web-guidance@googlechrome"
MWG_TIMEOUT=300
if ! command -v claude >/dev/null 2>&1; then
  warn "$MWG_PLUGIN not installed: Claude Code is missing; install it, then run this script again"
elif claude plugin list 2>/dev/null | grep -q "$MWG_PLUGIN"; then
  gtimeout "$MWG_TIMEOUT" claude plugin marketplace update googlechrome </dev/null >/dev/null 2>&1 \
    && gtimeout "$MWG_TIMEOUT" claude plugin update "$MWG_PLUGIN" </dev/null >/dev/null 2>&1 \
    && ok "$MWG_PLUGIN updated" || warn "$MWG_PLUGIN update failed; run this script again"
else
  gtimeout "$MWG_TIMEOUT" claude plugin install modern-web-guidance \
    --marketplace GoogleChrome/modern-web-guidance </dev/null >/dev/null 2>&1 \
    && ok "$MWG_PLUGIN" || warn "$MWG_PLUGIN failed to install; run this script again"
fi

# ─── Clean up
# Homebrew keeps every downloaded installer (several GB); the apps are installed,
# so delete the downloads and old versions.
log "Clean up"
brew cleanup --prune=all >/dev/null 2>&1 && ok "Homebrew downloads removed" || warn "brew cleanup failed"

# ─── Result
log "Done"
if [ ${#FAILS[@]} -eq 0 ]; then ok "Everything succeeded"
else printf '  These items need another look:\n'; for x in "${FAILS[@]}"; do printf '   - %s\n' "$x"; done; fi
echo
echo "Reminder: font sync keeps \"AvalonLotus - Font\" in the company folder and in Google Drive (My Drive, same path) in step; sign in to Google Drive so it can reach the Drive copy."