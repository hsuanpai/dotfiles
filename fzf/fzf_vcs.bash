#!/usr/bin/env bash

__fzf-p4-strip-common-ancestors() {                                                                                #{{{1
  for item in "$@"; do
    [[ -z "$item" ]] && continue

    if [[ "$STEM/$item" =~ "$PWD" ]]; then
      # Remove any common ancestors from filename
      item="$STEM/$item"
      item=${item##$PWD/}
      echo "$item";
    else
      echo "$STEM/$item";
    fi
  done
}

__fzf-down() {                                                                                                     #{{{1
  # fzf "$@" --height 50% --border
  fzf "$@"
}


fzf-git-diffs() {                                                                                                  #{{{1
  vcs__is_in_git_repo || return
  git -c color.status=always status --short |
  __fzf-down -m --ansi --nth 2..,.. \
    --preview '(git diff --color=always -- {-1} | sed 1,4d; cat {-1}) | head -500' |
  cut -c4- | sed 's/.* -> //'
}


fzf-git-branches() {                                                                                               #{{{1
  vcs__is_in_git_repo || return
  git branch -a --color=always | grep -v '/HEAD\s' | sort |
  __fzf-down --ansi --multi --tac --preview-window right:70% \
    --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< {} | cut -d" " -f1) | head -'$LINES |
  sed 's/^..//' | cut -d' ' -f1 |
  sed 's#^remotes/##'
}


fzf-git-tags() {                                                                                                   #{{{1
  vcs__is_in_git_repo || return
  git tag --sort -version:refname |
  __fzf-down --multi --preview-window right:70% \
    --preview 'git show --color=always {} | head -'$LINES
}


fzf-git-hashes() {                                                                                                 #{{{1
  vcs__is_in_git_repo || return
  git log --graph --color --all --date=short --pretty=format:' %C(yellow)%h%C(reset) %s %C(green)(%cd) %C(red)%d%C(reset)' |
  __fzf-down --ansi --no-sort --multi --bind 'ctrl-s:toggle-sort' \
    --header 'Press CTRL-S to toggle sort' \
    --preview 'grep -o "[a-f0-9]\{7,\}" <<< {} | xargs git show --color=always' |
  command grep -o "[a-f0-9]\{7,\}"
}


fzf-git-remotes() {                                                                                                #{{{1
  vcs__is_in_git_repo || return
  git remote -v | awk '{print $1 "\t" $2}' | uniq |
  __fzf-down --tac \
    --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" {1} | head -200' |
  cut -d$'\t' -f1
}


__fzf_p4_walist__() {                                                                                              #{{{1
  FZF_ALT_C_COMMAND='wals' __fzf_cd__
}


__fzf-p4-cd() {                                                                                                    #{{{1
  local cmd='command find $STEM -mindepth 1 \
    -type d \( -path $STEM/_env -o -path $STEM/emu -o -path $STEM/env_squash -o -path $STEM/import -o \
      -path $STEM/powerPro -o -path $STEM/sdpx \) -prune \
    -o -type d -print 2> /dev/null | sed "s:$STEM/::"'

  local dir=$(eval "$cmd" | FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd) +m)
  if [[ -z "$dir" ]]; then
    return
  fi

  printf '%q ' "$dir"
}


# Creating a separate function to allow overriding it from a project-specific rc file
__fzf-vcs-all-files-p4() {
  FZF_CTRL_T_COMMAND='cat \
    <(command p4 have ${STEM:+$STEM/}...) \
    <(p4 opened 2> /dev/null | command grep add | command sed "s/#.*//" | command xargs -I{} -n1 command p4 where {}) \
    | command awk "{print \$3}"' \
  fzf-file-widget
}


fzf-vcs-cd() {                                                                                                     #{{{1
  if vcs__is_in_perforce_repo; then
    __fzf-p4-cd
  else
    __fzf_cd__
  fi
}


fzf-vcs-all-files() {                                                                                              #{{{1
  if vcs__is_in_git_repo; then
    local _top=$(git rev-parse --show-toplevel)
    local _selected=$(git ls-tree --full-tree -r --name-only HEAD |
      FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" fzf -m |
      while read -r item; do
        path=${_top}/$item
        printf '%q ' "${path#$(realpath $PWD)/}"
      done
    )

    READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$_selected${READLINE_LINE:$READLINE_POINT}"
    READLINE_POINT=$(( READLINE_POINT + ${#_selected} ))
  elif vcs__is_in_perforce_repo; then
    __fzf-vcs-all-files-p4
  else
    fzf-file-widget
  fi
}


fzf-vcs-files() {                                                                                                  #{{{1
  if vcs__is_in_git_repo; then
    FZF_CTRL_T_COMMAND='{ git ls-tree -r --name-only HEAD || \
      find . -path "*/\.*" -prune -o -type f -print -o -type l -print | sed s/^..//; } 2> /dev/null' \
      fzf-file-widget
  elif vcs__is_in_perforce_repo; then
    FZF_CTRL_T_COMMAND='cat \
        <(p4 have ... | command awk "{print \$3}") \
        <(command p4 opened 2> /dev/null | command grep add | command sed "s/#.*//" | \
          command xargs -I{} -n1 command p4 where {} | command awk "{print \$3}") 2> /dev/null | \
      command sed "s:$PWD/::"' \
    fzf-file-widget
  else
    fzf-file-widget
  fi
}


fzf-vcs-commits() {                                                                                                #{{{1
  if vcs__is_in_git_repo; then
    fzf-git-hashes "$@"
  elif vcs__is_in_perforce_repo; then
    if [[ ! "$*" =~ -m\ \[0-9]+ ]]; then
      local _limit="-m 1000"
    fi
    p4 changes $_limit "$@" $STEM/... | sed -r 's/@\S*//' |
      __fzf-down --ansi --multi --no-sort --with-nth='..6' \
      --preview 'p4 describe -s {2}' --preview-window right:70% |
      cut -d' ' -f2
  fi
}


fzf-vcs-filelog() {                                                                                                #{{{1
  vcs__is_in_perforce_repo || return

  if [[ -n "$1" ]] && [[ $1 != -* ]] && [[ -f "$1" ]]; then
    local _file="$1"
    shift
  else
    local _file=$(cat \
      <(p4 have $STEM/... | command awk "{print \$3}") \
      <(command p4 opened 2> /dev/null | command grep add | command sed "s/#.*//" |
      command xargs -I{} -n1 command p4 where {} | command awk "{print \$3}") 2> /dev/null | command sed "s:$PWD/::" |
      fzf +m)
  fi
  [[ -z "$_file" ]] && return

  p4 filelog -s "$@" $_file |
    grep '^\.\.\.' | column -s' ' -o' ' -t | sed -r 's/@\S*//' |
    __fzf-down --ansi --header='filelog for '$(basename $_file) --multi --no-sort --with-nth='2..9' \
    --preview 'p4 describe -s {4}' --preview-window right:70% |
    cut -d' ' -f4
}


fzf-vcs-status() {                                                                                                 #{{{1
  if vcs__is_in_git_repo; then
    local _selected=$(git -c color.status=always status --short |
      FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" fzf -m --nth=2 |
      awk '{print $NF}' |
      while read -r item; do
        printf '%q ' "$item"
      done
    )
  elif vcs__is_in_perforce_repo; then
    local _selected=$(p4 opened 2> /dev/null | sed -r -e "s:^//depot/[^/]*/(trunk|branches/[^/]*)/::" |
      column -s# -o "    #" -t | column -s- -o- -t |
      FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" fzf -m --nth=1 | awk '{print $1}' |
      while read -r item; do
        path=${STEM}/$item
        printf '%q ' "${path#$(realpath $PWD)/}"
      done
    )
  fi

  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$_selected${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$(( READLINE_POINT + ${#_selected} ))
}
