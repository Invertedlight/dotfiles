# shellcheck shell=sh
# ~/.config/shell/ssh-agent.sh -- managed by chezmoi (Invertedlight/dotfiles)
#
# Reuse a reachable ssh-agent, or start exactly ONE per user on a fixed socket.
# Safe to source from sh, bash and zsh on every login; it never stacks agents.
#
# Order:
#   1. macOS only: ignore Apple's launchd agent socket (/var/run/com.apple.launchd.*
#      or /private/tmp/com.apple.launchd.*). The Homebrew OpenSSH agent is used
#      instead because it supports the FIDO "-sk" keys (existing behaviour kept).
#   2. $SSH_AUTH_SOCK already set and reachable (`ssh-add -l` exit 0 or 1)
#      -> reuse it. Covers agent forwarding (ssh -A, Cursor, DevPod) and shells
#      started from a shell that already has an agent.
#   3. ~/.ssh/ssh-agent.env exists -> source it and test the same way.
#   4. Fixed socket already has a live agent -> reuse it.
#   5. Otherwise remove a stale socket file, start `ssh-agent -a <fixed socket>`
#      and write ~/.ssh/ssh-agent.env atomically (mode 600).
# Fixed socket: $XDG_RUNTIME_DIR/ssh-agent.sock on Linux when that directory is
# usable, otherwise ~/.ssh/agent.sock. Two logins racing for it cannot both
# start an agent: the loser's bind fails and it reuses the winner's socket.

_dot_agent_ok() {
  # 0 = keys loaded, 1 = agent reachable but empty, 2 = cannot connect.
  [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ] || return 1
  ssh-add -l >/dev/null 2>&1
  [ $? -le 1 ]
}

_dot_agent_setup() {
  command -v ssh-agent >/dev/null 2>&1 || return 0
  command -v ssh-add >/dev/null 2>&1 || return 0

  _dot_env_file="$HOME/.ssh/ssh-agent.env"
  _dot_os="$(uname -s 2>/dev/null)"

  if [ "$_dot_os" = "Darwin" ]; then
    case "${SSH_AUTH_SOCK:-}" in
      /var/run/com.apple.launchd.*|/private/tmp/com.apple.launchd.*)
        unset SSH_AUTH_SOCK SSH_AGENT_PID ;;
    esac
    _dot_sock="$HOME/.ssh/agent.sock"
  elif [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ] && [ -w "$XDG_RUNTIME_DIR" ]; then
    _dot_sock="$XDG_RUNTIME_DIR/ssh-agent.sock"
  else
    _dot_sock="$HOME/.ssh/agent.sock"
  fi

  # 2. inherited / forwarded agent
  if _dot_agent_ok; then export SSH_AUTH_SOCK; return 0; fi

  # 3. agent recorded by a previous login
  if [ -r "$_dot_env_file" ]; then
    # shellcheck disable=SC1090
    . "$_dot_env_file" >/dev/null 2>&1
    case "${SSH_AUTH_SOCK:-}" in
      /var/run/com.apple.launchd.*|/private/tmp/com.apple.launchd.*)
        [ "$_dot_os" = "Darwin" ] && unset SSH_AUTH_SOCK SSH_AGENT_PID ;;
    esac
    if _dot_agent_ok; then export SSH_AUTH_SOCK SSH_AGENT_PID; return 0; fi
  fi

  # 4. agent already listening on the fixed socket
  SSH_AUTH_SOCK="$_dot_sock"; unset SSH_AGENT_PID
  if _dot_agent_ok; then export SSH_AUTH_SOCK; return 0; fi

  # 5. start one
  [ -d "$HOME/.ssh" ] || { mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"; }
  if [ -e "$_dot_sock" ] || [ -L "$_dot_sock" ]; then rm -f "$_dot_sock"; fi
  if _dot_out="$(ssh-agent -s -a "$_dot_sock" 2>/dev/null)"; then
    eval "$_dot_out" >/dev/null
  fi
  SSH_AUTH_SOCK="$_dot_sock"
  if _dot_agent_ok; then
    export SSH_AUTH_SOCK
    [ -n "${SSH_AGENT_PID:-}" ] && export SSH_AGENT_PID
    _dot_tmp="$_dot_env_file.tmp.$$"
    if ( umask 077
         { printf 'SSH_AUTH_SOCK=%s; export SSH_AUTH_SOCK;\n' "$SSH_AUTH_SOCK"
           [ -n "${SSH_AGENT_PID:-}" ] && printf 'SSH_AGENT_PID=%s; export SSH_AGENT_PID;\n' "$SSH_AGENT_PID"
           : ; } > "$_dot_tmp" ) 2>/dev/null; then
      mv -f "$_dot_tmp" "$_dot_env_file"
    else
      rm -f "$_dot_tmp"
    fi
    return 0
  fi
  unset SSH_AUTH_SOCK SSH_AGENT_PID
  return 0
}

_dot_agent_setup
unset -f _dot_agent_setup _dot_agent_ok
unset _dot_env_file _dot_os _dot_sock _dot_out _dot_tmp
