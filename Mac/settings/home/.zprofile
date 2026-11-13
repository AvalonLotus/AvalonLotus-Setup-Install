eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_NO_EMOJI=1
# python3 and pip3 mean Homebrew Python 3.14, where install.sh puts the user packages;
# their commands (markitdown and others) are in ~/Library/Python/3.14/bin.
export PATH="/opt/homebrew/opt/python@3.14/libexec/bin:$HOME/Library/Python/3.14/bin:$PATH"
