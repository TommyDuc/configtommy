#!/usr/bin/env bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#  /\ /\ _ __   ___| | ___  /__   \___  _ __ ___   ( )__    #
# / / \ \ '_ \ / __| |/ _ \   / /\/ _ \| '_ ` _ \  |/ __|   #
# \ \_/ / | | | (__| |  __/  / / | (_) | | | | | |  \__ \   #
#  \___/|_| |_|\___|_|\___|  \/   \___/|_| |_| |_|  |___/   #
#    _               _                                      #
#   | |__   __ _ ___| |__  _ __ ___                         #
#   | '_ \ / _` / __| '_ \| '__/ __|                        #
#  _| |_) | (_| \__ \ | | | | | (__                         #
# (_)_.__/ \__,_|___/_| |_|_|  \___|                        #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# add ~/bin to PATH
PATH="$HOME/bin:$PATH"

# brew
PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

# go
PATH="$HOME/go/bin:$PATH"

# pip
PATH="$HOME/.local/bin:$PATH"

# pyenv
PATH="$HOME/.pyenv/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
. "$HOME/.cargo/env"

# git
# source /home/tommy/projects/misc/git-subrepo/.rc
alias cdg="cd \"\$(git rev-parse --show-toplevel)\"" # cd to root of current git repo
alias lg=lazygit # update with go install github.com/jesseduffield/lazygit@latest
alias dag="git dag --all &" # GUI display of the dag from git-cola

[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"

# nix
alias nix_dev='nix develop --extra-experimental-features nix-command --extra-experimental-features flakes'

# tere
tere() {
    local result=$(command tere "$@")
    [ -n "$result" ] && cd -- "$result"
}

# tree
# --gitignore: do not list files matched in .gitignore files
# -a: show hidden files starting with '.'
# -I '.git': ignore files inside the '.git' folder
alias tree="tree --gitignore -a -I '.git'"
# Include everyting. Let the bodies hit the floor. Let the bodies hit the floor. That's how I roll now.
alias atree="tree -a"

# zellij
alias z="zellij"

# openvpn3
alias start_ov="openvpn3 session-start --config"
alias stop_ov="openvpn3 session-manage -D --config"

# neovim
alias nvim="/usr/local/bin/nvim"
alias vim="nvim"
alias vi="nvim"
alias o="nvim ."
alias gnvim="alacritty -e nvim"
export EDITOR='nvim'

# direnv
eval "$(direnv hook bash)"
export DIRENV_LOG_FORMAT=''

# starship
eval "$(starship init bash)"

# just
eval "$(just --completions bash)"
alias j='just'

# misc
alias batp="\$HOME/.cargo/bin/bat --force-colorization --theme dark --paging always"
alias batc="\$HOME/.cargo/bin/bat --force-colorization --theme dark --paging never"
alias pp="xclip -selection clipboard -rmlastnl" # Pipe to system clipboard

# opencode
export PATH=/home/tommy/.opencode/bin:$PATH
alias oc="opencode --agent plan" # Always start in agent mode
alias occ="oc -c" # Continue from last sessiion

# nodejs
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
