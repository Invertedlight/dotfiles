# shellcheck shell=sh
# ~/.config/shell/brew-env.sh -- managed by chezmoi (Invertedlight/dotfiles)
#
# Put Homebrew on PATH if (and only if) it is installed. Safe to source from
# sh, bash and zsh, any number of times, on macOS and Linux.
#   macOS : /opt/homebrew (Apple Silicon), /usr/local (Intel)
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
  # Already set up by a parent shell? Skip so PATH does not grow on nesting.
  case ":${PATH}:" in
    *":${_dot_brew_prefix}/bin:"*) [ "${HOMEBREW_PREFIX:-}" = "$_dot_brew_prefix" ] || eval "$("$_dot_brew" shellenv)" ;;
    *) eval "$("$_dot_brew" shellenv)" ;;
  esac
fi
unset _dot_brew _dot_brew_prefix
