# Minimal .zshrc for iTerm2 recording / screencast sessions.
#
# Used via ZDOTDIR from iterm_for_recordly.applescript.
# When ZDOTDIR is set, zsh ignores $HOME/.zsh* startup files, so we
# re-source them manually to preserve aliases, PATH tweaks, completions,
# iTerm2 shell integration, etc.
[[ -f "$HOME/.zshenv"   ]] && source "$HOME/.zshenv"
[[ -f "$HOME/.zprofile" ]] && source "$HOME/.zprofile"
[[ -f "$HOME/.zshrc"    ]] && source "$HOME/.zshrc"

# Clean prompt for screencasts. No left decorations, no right-side prompt.
PROMPT='$ '
RPROMPT=''
