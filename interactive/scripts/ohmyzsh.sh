#!/bin/sh
: "${ZSH:?ZSH must be set}"
CHSH=${CHSH:-yes}
RUNZSH=${RUNZSH:-yes}
KEEP_ZSHRC=${KEEP_ZSHRC:-no}
zdot="${ZDOTDIR:-$HOME}"

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

user_can_sudo() {
  command_exists sudo || return 1
  case "$PREFIX" in *com.termux*) return 1 ;; esac
  ! LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"
}

setup_zshrc() {
  OLD_ZSHRC="$zdot/.zshrc.pre-oh-my-zsh"
  if [ -f "$zdot/.zshrc" ] || [ -h "$zdot/.zshrc" ]; then
    [ "$KEEP_ZSHRC" = yes ] && return
    [ -e "$OLD_ZSHRC" ] && mv "$OLD_ZSHRC" "${OLD_ZSHRC}-$(date +%Y-%m-%d_%H-%M-%S)"
    mv "$zdot/.zshrc" "$OLD_ZSHRC"
  fi
  omz=$(echo "$ZSH" | sed "s|^$HOME/|\$HOME/|")
  sed "s|^export ZSH=.*$|export ZSH=\"${omz}\"|" "$ZSH/templates/zshrc.zsh-template" > "$zdot/.zshrc"
}

setup_shell() {
  [ "$CHSH" = no ] && return
  [ "$(basename -- "$SHELL")" = "zsh" ] && return
  command_exists chsh || return
  case "$PREFIX" in
    *com.termux*) zsh=zsh ;;
    *)
      shells_file=/etc/shells
      [ -f "$shells_file" ] || shells_file=/usr/share/defaults/etc/shells
      [ -f "$shells_file" ] || return
      zsh=$(command -v zsh) && grep -qx "$zsh" "$shells_file" || zsh=$(grep '^/.*/zsh$' "$shells_file" | tail -n 1)
      [ -f "$zsh" ] || return
      ;;
  esac
  [ -n "$SHELL" ] && echo "$SHELL" > "$zdot/.shell.pre-oh-my-zsh"
  if user_can_sudo; then sudo -k chsh -s "$zsh" "$USER"; else chsh -s "$zsh" "$USER"; fi
}
[ ! -t 0 ] && RUNZSH=no CHSH=no
while [ $# -gt 0 ]; do
  case $1 in
    --unattended) RUNZSH=no; CHSH=no ;;
    --skip-chsh) CHSH=no ;;
    --keep-zshrc) KEEP_ZSHRC=yes ;;
  esac
  shift
done
command_exists zsh || { echo "Zsh not installed" >&2; exit 1; }
[ -d "$ZSH/.git" ] && [ -f "$ZSH/templates/zshrc.zsh-template" ] || { echo "Invalid ZSH dir: $ZSH" >&2; exit 1; }
[ -n "$ZDOTDIR" ] && mkdir -p "$ZDOTDIR"
setup_zshrc
setup_shell
[ "$RUNZSH" = no ] && echo "Run zsh to try it out."