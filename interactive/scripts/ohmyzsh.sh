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
    if [ "$KEEP_ZSHRC" = yes ]; then
      echo "Found ~/.zshrc. Keeping..."
      return
    fi
    printf 'Do you want to overwrite your existing .zshrc? [Y/n] '
    read -r opt
    case $opt in
      [Yy]*|"") ;;
      [Nn]*) echo "Overwrite skipped."; return ;;
      *) echo "Invalid choice. Skipped."; return ;;
    esac

    if [ -e "$OLD_ZSHRC" ]; then
      mv "$OLD_ZSHRC" "${OLD_ZSHRC}-$(date +%Y-%m-%d_%H-%M-%S)"
    fi
    mv "$zdot/.zshrc" "$OLD_ZSHRC"
  fi
  omz=$(echo "$ZSH" | sed "s|^$HOME/|\$HOME/|")
  sed "s|^export ZSH=.*$|export ZSH=\"${omz}\"|" "$ZSH/templates/zshrc.zsh-template" > "$zdot/.zshrc"
}

setup_shell() {
  [ "$CHSH" = no ] && return
  [ "$(basename -- "$SHELL")" = "zsh" ] && return
  command_exists chsh || return
  printf 'Do you want to change your default shell to zsh? [Y/n] '
  read -r opt
  case $opt in
    [Yy]*|"") ;; # Continue
    [Nn]*) echo "Shell change skipped."; return ;;
    *) echo "Invalid choice. Skipped."; return ;;
  esac

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
setup_zshrc
setup_shell
if [ "$RUNZSH" = no ]; then
  echo "Run zsh to try it out."
else
  exec zsh -l
fi