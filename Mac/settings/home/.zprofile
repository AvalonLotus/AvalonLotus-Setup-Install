# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:$HOME/.docker/bin"
# End of Docker Desktop section.

eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_NO_EMOJI=1
# python3 and pip3 mean Homebrew Python 3.14, where install.sh puts the user packages;
# their commands (markitdown and others) are in ~/Library/Python/3.14/bin.
export PATH="/opt/homebrew/opt/python@3.14/libexec/bin:$HOME/Library/Python/3.14/bin:$PATH"
# Rust build output goes to a local folder outside the company folder and cloud-synced folders.
export CARGO_TARGET_DIR="$HOME/Developer/cargo-target"
# Opt out of usage telemetry in tools that honour it (Modern Web Guidance, Claude Code).
export DISABLE_TELEMETRY=1
