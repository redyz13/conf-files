# ~/.bashrc

# Exit if not interactive shell
[[ $- != *i* ]] && return

# ➤ History settings
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Auto-adjust terminal size
shopt -s checkwinsize

# Lesspipe support
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Bell off
bind 'set bell-style none'

# Bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Source z
[ -f "$HOME/.zpath/z.sh" ] && . "$HOME/.zpath/z.sh"

# Aliases

# General aliases
alias ..='cd ..'
alias ls='ls -lha --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias vim='nvim'
alias y='xclip -selection clipboard'

# Pacman
alias update-all='sudo pacman -Syuu'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'

# APT
alias aptup='sudo apt update && sudo apt upgrade'
alias aptupd='sudo apt update'
alias aptupg='sudo apt upgrade'
alias aptins='sudo apt install'
alias aptrmv='sudo apt remove'
alias aptpur='sudo apt purge'

# Alert for long commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Prompt
PS1='[\u@\h \W]\$ '

# Color scheme via pywal
wal -q -e -n -i "$HOME/Wallpapers/lain.jpg"
cat "$HOME/.cache/wal/sequences" &> /dev/null &
cat "$HOME/.cache/wal/sequences"
[ -f "$HOME/.cache/wal/colors-tty.sh" ] && source "$HOME/.cache/wal/colors-tty.sh"

# Cat
export PATH=$PATH:$HOME/.cpath
fm6000 -f ~/.cpath/cat.txt

# Node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

[ -f ~/.config/nnn/env ] && source ~/.config/nnn/env

