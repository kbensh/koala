#!/bin/sh
: "${ZSH:?ZSH must be set}"
CHSH=${CHSH:-yes}
RUNZSH=${RUNZSH:-yes}
KEEP_ZSHRC=${KEEP_ZSHRC:-no}
zdot="${ZDOTDIR:-$HOME}"
USER=${USER:-$(id -u -n)}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

setup_zshrc() {
  OLD_ZSHRC="$zdot/.zshrc.pre-oh-my-zsh"
  if [ -f "$zdot/.zshrc" ] || [ -h "$zdot/.zshrc" ]; then
    if [ "$KEEP_ZSHRC" = yes ]; then
      echo "Found .zshrc. Keeping..."
      return
    fi

    # Prompt user
    printf 'Do you want to overwrite your existing .zshrc? [Y/n] '
    read -r opt
    case $opt in
      [Yy]*|"") ;;
      *) echo "Overwrite skipped."; return ;;
    esac

    # Backup existing
    if [ -e "$OLD_ZSHRC" ]; then
      OLD_OLD_ZSHRC="${OLD_ZSHRC}-$(date +%Y-%m-%d_%H-%M-%S)"
      mv "$OLD_ZSHRC" "${OLD_OLD_ZSHRC}"
    fi
    mv "$zdot/.zshrc" "$OLD_ZSHRC"
    echo "Found old .zshrc. Backing up to ${OLD_ZSHRC}"
  fi
  sed "s|^export ZSH=.*$|export ZSH=\"$ZSH\"|" "$ZSH/templates/zshrc.zsh-template" > "$zdot/.zshrc"
  echo
}

setup_shell() {
  [ "$CHSH" = no ] && return
  [ "$(basename -- "$SHELL")" = "zsh" ] && return

  printf 'Do you want to change your default shell to zsh? [Y/n] '
  read -r opt
  case $opt in
    [Yy]*|"") ;;
    *) echo "Shell change skipped."; return ;;
  esac

  zsh_path=$(command -v zsh)
  
  echo "Changing your shell to $zsh_path..."
  # Try standard chsh
  if ! chsh -s "$zsh_path" "$USER"; then
      printf "chsh command unsuccessful. Change your default shell manually."
  else
      echo "Shell successfully changed to '$zsh_path'."
  fi
  echo
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
