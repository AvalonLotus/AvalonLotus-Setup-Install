<p align="center"><img src="../assets/avalonlotus-stacked-white-on-black-banner.png" width="100%" alt="AvalonLotus"></p>

<p align="center">Design is not measured by its form, but by the lives it changes.</p>

# AvalonLotus Mac Setup

## Usage

1. Sign in to the App Store.
2. In Terminal, run the one-line install:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AvalonLotus/AvalonLotus-Setup-Install/main/Mac/bootstrap.sh)"
   ```

   Or put this whole folder anywhere on the Mac and run `bash "<this folder>/install.sh"`.
3. Sign in to Google Drive and set the "AvalonLotus Mac - Font" folder to Available offline (font sync needs it).

The script can be run again at any time; anything already installed is skipped.

## What It Installs

| Category | Contents |
|---|---|
| Command-line tools | gh, node, python, rust, ffmpeg, yt-dlp, tesseract (with Traditional Chinese), pandoc, poppler, whisper-cpp, opencc, git-lfs, xcodegen, mas, cloudflared, ollama, powershell, rclone, ripgrep, opencode, 7zip, coreutils |
| Apps | Docker, Chrome, Discord, Telegram, Claude, Claude Code, ChatGPT, Codex, Grok Bot, VS Code, Rectangle, AppCleaner, IINA, OBS, Obsidian, LibreOffice, Google Drive |
| App Store | Xcode, LINE, WhatsApp, Dashlane, Surfshark, Keynote, Numbers, Pages, GarageBand, iMovie |
| Python packages | `settings/requirements-user.txt`, `settings/requirements-system-python.txt` |
| transcribe | Local speech-to-text for recordings, with the large-v3 speech model |
| Font sync | Two-way sync with the Drive folder "AvalonLotus Mac - Font" at login and every 30 minutes |
| Mac settings | Click wallpaper to show desktop, bottom-left and bottom-right hot corners, screen saver delay, Terminal settings, Git identity |

## Files

| File | Purpose |
|---|---|
| `bootstrap.sh` | One-line install: downloads this repo with curl and tar, then runs `install.sh` |
| `install.sh` | Installs everything above; copies this folder to the hidden `~/.local/share/avalonlotus-mac-setup` first and removes Homebrew downloads at the end |
| `transcribe.sh` | `transcribe <audio-or-video-file> [output-dir]`; writes `.txt` and `.srt`; audio never leaves the Mac |
| `settings/fonts-sync.sh`, `settings/font_sync.py`, `settings/font_names.py` | Font sync, run by the LaunchAgent `com.avalonlotus.font-sync` |
| `settings/home/.zprofile` | Terminal settings copied to `~/.zprofile` (the old file is backed up) |
| `settings/homebrew-curlrc` | Download speed limits for Homebrew |
