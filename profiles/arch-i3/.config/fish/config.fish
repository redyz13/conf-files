if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Remove greeting
set -g fish_greeting

# Tilde key
bind -k npage 'commandline -a \~; commandline -f forward-char'

if test -z "$DISPLAY"; and test "$XDG_VTNR" = "1"
    exec startx
end

# Color scheme via pywal
wal -q -e -n -R
cat "$HOME/.cache/wal/sequences" > /dev/null 2>&1 &
if test -f "$HOME/.cache/wal/colors-tty.sh"
    bash "$HOME/.cache/wal/colors-tty.sh"
end

# Cat
fish_add_path $HOME/.cpath
fm6000 -f ~/.cpath/cat.txt

# Aliases

# General aliases
alias ..='cd ..'
alias ls='exa -alF'
alias ll='exa -ha'
alias vim='nvim'
alias y='xclip -selection clipboard'

# Pacman
alias update-all='sudo pacman -Syuu'
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'

# Apt
alias aptup='sudo apt update && sudo apt upgrade'
alias aptupd='sudo apt update'
alias aptupg='sudo apt upgrade'
alias aptins='sudo apt install'
alias aptrmv='sudo apt remove'
alias aptpur='sudo apt purge'

# Run nvm
nvm use lts > /dev/null

# Sashimi
function fish_prompt
  set -l last_status $status
  set -l cyan (set_color -o cyan)
  set -l yellow (set_color -o yellow)
  set -g red (set_color -o red)
  set -g blue (set_color -o blue)
  set -l green (set_color -o green)
  set -g normal (set_color normal)

  set -l ahead (_git_ahead)
  set -g whitespace ' '

  if test $last_status = 0
    set initial_indicator "$green◆"
    set status_indicator "$normal❯$cyan❯$green❯"
  else
    set initial_indicator "$red✖ $last_status"
    set status_indicator "$red❯$red❯$red❯"
  end
  set -l cwd $cyan(basename (prompt_pwd))

  if [ (_git_branch_name) ]

    if test (_git_branch_name) = 'master'
      set -l git_branch (_git_branch_name)
      set git_info "$normal git:($red$git_branch$normal)"
    else
      set -l git_branch (_git_branch_name)
      set git_info "$normal git:($blue$git_branch$normal)"
    end

    if [ (_is_git_dirty) ]
      set -l dirty "$yellow ✗"
      set git_info "$git_info$dirty"
    end
  end

  # Notify if a command took more than 5 minutes
  if [ "$CMD_DURATION" -gt 300000 ]
    echo The last command took (math "$CMD_DURATION/1000") seconds.
  end

  echo -n -s $initial_indicator $whitespace $cwd $git_info $whitespace $ahead $status_indicator $whitespace
end

function _git_ahead
  set -l commits (command git rev-list --left-right '@{upstream}...HEAD' 2>/dev/null)
  if [ $status != 0 ]
    return
  end
  set -l behind (count (for arg in $commits; echo $arg; end | grep '^<'))
  set -l ahead  (count (for arg in $commits; echo $arg; end | grep -v '^<'))
  switch "$ahead $behind"
    case ''     # no upstream
    case '0 0'  # equal to upstream
      return
    case '* 0'  # ahead of upstream
      echo "$blue↑$normal_c$ahead$whitespace"
    case '0 *'  # behind upstream
      echo "$red↓$normal_c$behind$whitespace"
    case '*'    # diverged from upstream
      echo "$blue↑$normal$ahead $red↓$normal_c$behind$whitespace"
  end
end

function _git_branch_name
  echo (command git symbolic-ref HEAD 2>/dev/null | sed -e 's|^refs/heads/||')
end

function _is_git_dirty
  echo (command git status -s --ignore-submodules=dirty 2>/dev/null)
end

