# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your flutter installation.
export PATH="$PATH:/home/ask/dev/flutter/bin"

export PATH="$HOME/.local/scripts:$PATH"

export PATH="$HOME/.local/bin:$PATH"

# Display red dots whilst waiting for completion (oh-my-zsh lib/completion.zsh).
COMPLETION_WAITING_DOTS="true"

# Plugins are managed by antidote (https://antidote.sh), which clones itself and
# every bundle on first start. Bundles are listed in ~/.zsh_plugins.txt; run
# `antidote update` to update them.
zstyle ':omz:update' mode disabled  # antidote updates oh-my-zsh
antidote_dir="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
[[ -d $antidote_dir ]] || git clone --depth=1 https://github.com/mattmc3/antidote.git "$antidote_dir"
source "$antidote_dir/antidote.zsh"
antidote load
unset antidote_dir

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# My own aliases
alias ..="cd .."
alias ll="ls -alh --color=auto"
alias :q="exit"
alias :qa="tmux kill-session"
alias tma='tmux a'
alias open='xdg-open'

# Jump and delete words using control key and arrow keys
bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word
bindkey "^H" backward-kill-word

# tmux sessionizer
bindkey -s "^f" "tmux-sessionizer \n"
bindkey -s "^t" "tmux new \n"
bindkey -s "^n" "nmtui \n"

# bun completions
[ -s "/home/ask/.bun/_bun" ] && source "/home/ask/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# pnpm
export PNPM_HOME="/home/ask/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Start ssh-agent if not running
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[[ -f /home/ask/.dart-cli-completion/zsh-config.zsh ]] && . /home/ask/.dart-cli-completion/zsh-config.zsh || true
## [/Completion]

HISTSIZE=10000
SAVEHIST=10000
