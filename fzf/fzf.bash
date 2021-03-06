#!/usr/bin/env bash
echo "$(tput setaf 2)Sourcing$(tput sgr0) ${BASH_SOURCE[0]} ..."

if [[ -z "$FZF_PATH" ]]; then
  _fg_red=$(tput setaf 1)
  _reset=$(tput sgr0)
  echo "${_fg_red}ERROR${_reset}: FZF_PATH is not set"
  return
fi

# Setup fzf
# ---------
[[ ! "$PATH" == *$FZF_PATH/bin* ]] && export PATH="$PATH:$FZF_PATH/bin"

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "$FZF_PATH/shell/completion.bash" 2> /dev/null

# Key bindings
# ------------
# Note the order is important because some functions get overridden
source $FZF_PATH/shell/key-bindings.bash
source ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/fzf/fzf_vcs.bash
source ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/fzf/key-bindings.bash

# Customisations
# --------------
if hash fd 2> /dev/null || hash fdfind 2> /dev/null; then
  export FZF_DEFAULT_COMMAND='fd --color=never --follow --hidden --exclude .git --type f'
  export FZF_ALT_C_COMMAND='fd --color=never --follow --hidden --exclude .git --type d'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --ansi --exit-0 --reverse --bind=ctrl-n:down,ctrl-p:up"
# export FZF_CTRL_T_OPTS='--expect=alt-v,alt-e,alt-c'
