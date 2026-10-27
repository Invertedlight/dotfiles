# shellcheck shell=sh
# ~/.config/shell/brew-env.sh -- managed by chezmoi (Invertedlight/dotfiles)
#
# Put Homebrew on PATH if (and only if) it is installed. Safe to source from
# sh, bash and zsh, any number of times, on macOS and Linux.
#   macOS : /opt/homebrew (Apple Silicon), /usr/local (Intel); /opt/homebrew wins
#           and is kept ahead of /usr/local/bin when both exist
#   Linux : /home/linuxbrew/.linuxbrew (default), ~/.linuxbrew (legacy)
# Prints nothing and never fails when brew is missing.

# Explicit tests (no word-splitting loop: zsh does not split unquoted vars).
_dot_brew=""
case "$(uname -s 2>/dev/null)" in
  Darwin)
    if   [ -x /opt/homebrew/bin/brew ]; then _dot_brew=/opt/homebrew/bin/brew
    elif [ -x /usr/local/bin/brew ];    then _dot_brew=/usr/local/bin/brew
    fi ;;
  Linux)
    if   [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then _dot_brew=/home/linuxbrew/.linuxbrew/bin/brew
    elif [ -x "$HOME/.linuxbrew/bin/brew" ];         then _dot_brew="$HOME/.linuxbrew/bin/brew"
    fi ;;
esac

if [ -n "$_dot_brew" ]; then
  _dot_brew_prefix="${_dot_brew%/bin/brew}"
  # Already first on PATH and set up by a parent shell? Nothing to do.
  case "${PATH}:" in
    "${_dot_brew_prefix}/bin:"*) [ "${HOMEBREW_PREFIX:-}" = "$_dot_brew_prefix" ] && _dot_brew="" ;;
  esac
  if [ -n "$_dot_brew" ]; then
    # Drop any existing <prefix>/bin and <prefix>/sbin entries (e.g. appended
    # by path_helper from /etc/paths.d/homebrew, after /usr/local/bin), then
    # let shellenv prepend them. Keeps Homebrew ahead of /usr/local/bin and
    # stops PATH growing on nested shells.
    _dot_new=""; _dot_rest="${PATH}:"
    while [ -n "$_dot_rest" ]; do
      _dot_e="${_dot_rest%%:*}"; _dot_rest="${_dot_rest#*:}"
      case "$_dot_e" in
        ""|"${_dot_brew_prefix}/bin"|"${_dot_brew_prefix}/sbin") ;;
        *) _dot_new="${_dot_new:+${_dot_new}:}${_dot_e}" ;;
      esac
    done
    PATH="$_dot_new"; export PATH
    eval "$("$_dot_brew" shellenv)"
  fi
fi
unset _dot_brew _dot_brew_prefix _dot_new _dot_rest _dot_e
