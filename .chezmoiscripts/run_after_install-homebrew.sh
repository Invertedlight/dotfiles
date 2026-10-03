#!/bin/bash
# Install Homebrew on macOS or Linux if it is missing.  Managed by chezmoi.
#
# Runs on every `chezmoi apply` but is idempotent: it exits immediately when
# brew already exists at the platform's standard prefix.  It never fails the
# apply; problems are reported as a "homebrew:" message and skipped.
#
#   macOS : /opt/homebrew (Apple Silicon) or /usr/local (Intel)
#   Linux : /home/linuxbrew/.linuxbrew  (prereqs: build-essential procps curl file git)
#
# Opt out on any machine with DOTFILES_SKIP_HOMEBREW=1.
# The official installer refuses to run as root, so a root run (e.g. the DevPod
# bootstrap init container) skips with a message; the next `chezmoi apply` as
# the normal user installs it.

set -u

say() { printf 'homebrew: %s\n' "$*" >&2; }

if [ "${DOTFILES_SKIP_HOMEBREW:-0}" = "1" ]; then
  say "DOTFILES_SKIP_HOMEBREW=1, skipping"
  exit 0
fi

os="$(uname -s)"
case "$os" in
  Darwin) candidates=(/opt/homebrew/bin/brew /usr/local/bin/brew) ;;
  Linux)  candidates=(/home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew") ;;
  *) say "unsupported OS '$os', skipping"; exit 0 ;;
esac

for b in "${candidates[@]}"; do
  if [ -x "$b" ]; then
    exit 0   # already installed, nothing to do (quiet on purpose)
  fi
done

if [ "$(id -u)" -eq 0 ]; then
  say "running as root; the Homebrew installer refuses root. Skipping."
  say "run 'chezmoi apply' as your normal user to install Homebrew."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  say "curl not found, skipping"
  exit 0
fi

# Passwordless sudo available?  (never prompts)
can_sudo=0
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  can_sudo=1
fi

if [ "$os" = "Linux" ]; then
  missing=()
  command -v gcc   >/dev/null 2>&1 || missing+=(build-essential)
  command -v make  >/dev/null 2>&1 || missing+=(build-essential)
  command -v ps    >/dev/null 2>&1 || missing+=(procps)
  command -v file  >/dev/null 2>&1 || missing+=(file)
  command -v git   >/dev/null 2>&1 || missing+=(git)
  if [ "${#missing[@]}" -gt 0 ]; then
    # de-duplicate
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u)
    if [ "$can_sudo" -eq 1 ] && command -v apt-get >/dev/null 2>&1; then
      say "installing prerequisites: ${missing[*]}"
      sudo -n env DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 || true
      if ! sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}" >/dev/null 2>&1; then
        say "could not install prerequisites (${missing[*]}), skipping"
        exit 0
      fi
    else
      say "missing prerequisites (${missing[*]}) and no passwordless sudo/apt-get, skipping"
      exit 0
    fi
  fi
  # The installer needs to create /home/linuxbrew (sudo) unless it already
  # exists and is writable by this user.
  if [ "$can_sudo" -eq 0 ] && ! [ -w /home/linuxbrew/.linuxbrew ] 2>/dev/null; then
    say "no passwordless sudo and /home/linuxbrew/.linuxbrew is not writable, skipping"
    exit 0
  fi
fi

# NONINTERACTIVE when there is no terminal or sudo is already passwordless.
# On macOS with a terminal and no cached sudo, the installer asks for the
# admin password itself.
if [ "$can_sudo" -eq 1 ] || ! [ -t 0 ]; then
  export NONINTERACTIVE=1
fi
if [ "$os" = "Darwin" ] && [ "${NONINTERACTIVE:-0}" = "1" ] && [ "$can_sudo" -eq 0 ]; then
  say "macOS install needs an admin password but there is no terminal, skipping"
  exit 0
fi

say "installing Homebrew (official installer)…"
installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
  say "could not download the installer, skipping"
  exit 0
fi
if /bin/bash "$installer"; then
  say "installed. Open a new login shell (or source ~/.config/shell/brew-env.sh) to use brew."
else
  say "installer exited with status $?, continuing without Homebrew"
fi
exit 0
