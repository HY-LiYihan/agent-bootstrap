#!/usr/bin/env bash
# Agent Bootstrap dispatcher for macOS/Linux.

set -euo pipefail
IFS=$'\n\t'

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-HY-LiYihan/agent-bootstrap}"
BOOTSTRAP_REF="${BOOTSTRAP_REF:-stable}"
AGENT="${AGENT:-}"
LOCAL_SOURCE="${AGENT_BOOTSTRAP_LOCAL_SOURCE:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$1"; }
ok() { printf "%b[OK]%b %s\n" "$GREEN" "$NC" "$1"; }
warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
fail() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2; exit 1; }

usage() {
  cat <<USAGE
Agent Bootstrap

Usage:
  AGENT=codex AGENT_TOKEN=... AGENT_BASE_URL=... bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
  AGENT=claudecode AGENT_TOKEN=... AGENT_BASE_URL=... bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
  AGENT=openclaw AGENT_TOKEN=... AGENT_BASE_URL=... bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
  AGENT=hermes AGENT_TOKEN=... AGENT_BASE_URL=... AGENT_MODEL=... bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
  AGENT=codexplusplus bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"

Aliases:
  codex, claudecode, claude, openclaw, hermes, hermes-agent, codexplusplus, codex++, cpp

You can also pass the agent as the first argument:
  bash -c "\$(curl -fsSL .../install.sh)" -- codex

Unified env:
  AGENT_TOKEN      Shared API token for the selected agent
  AGENT_BASE_URL   Shared gateway/base URL for the selected agent
  AGENT_MODEL      Optional model value for agents that support it
  CODEX_PLUS_PLUS_REF  Optional upstream Codex++ ref/tag (default: v1.0.7)
USAGE
}

normalize_agent() {
  case "$1" in
    codex|openai-codex) printf "codex" ;;
    claude|claudecode|claude-code) printf "claudecode" ;;
    openclaw|claw) printf "openclaw" ;;
    hermes|hermes-agent) printf "hermes" ;;
    codexplusplus|codex-plus-plus|codex++|cpp) printf "codexplusplus" ;;
    *) return 1 ;;
  esac
}

prepare_agent_env() {
  local normalized="$1"

  case "$normalized" in
    codex)
      if [[ -n "${AGENT_TOKEN:-}" && -z "${CODEX_TOKEN:-}" ]]; then export CODEX_TOKEN="$AGENT_TOKEN"; fi
      if [[ -n "${AGENT_BASE_URL:-}" && -z "${CODEX_API_URL:-}" ]]; then export CODEX_API_URL="$AGENT_BASE_URL"; fi
      if [[ -n "${AGENT_MODEL:-}" && -z "${CODEX_MODEL:-}" ]]; then export CODEX_MODEL="$AGENT_MODEL"; fi
      ;;
    claudecode)
      if [[ -n "${AGENT_TOKEN:-}" && -z "${CLAUDE_TOKEN:-}" ]]; then export CLAUDE_TOKEN="$AGENT_TOKEN"; fi
      if [[ -n "${AGENT_TOKEN:-}" && -z "${CLAUDE_CLIENT_TOKEN:-}" ]]; then export CLAUDE_CLIENT_TOKEN="$AGENT_TOKEN"; fi
      if [[ -n "${AGENT_BASE_URL:-}" && -z "${CLAUDE_API_URL:-}" ]]; then export CLAUDE_API_URL="$AGENT_BASE_URL"; fi
      ;;
    openclaw)
      if [[ -n "${AGENT_TOKEN:-}" && -z "${OPENCLAW_TOKEN:-}" ]]; then export OPENCLAW_TOKEN="$AGENT_TOKEN"; fi
      if [[ -n "${AGENT_BASE_URL:-}" && -z "${OPENCLAW_BASE_URL:-}" ]]; then export OPENCLAW_BASE_URL="$AGENT_BASE_URL"; fi
      if [[ -n "${AGENT_MODEL:-}" && -z "${OPENCLAW_MODEL:-}" ]]; then export OPENCLAW_MODEL="$AGENT_MODEL"; fi
      ;;
    hermes)
      if [[ -n "${AGENT_TOKEN:-}" && -z "${HERMES_API_KEY:-}" ]]; then export HERMES_API_KEY="$AGENT_TOKEN"; fi
      if [[ -n "${AGENT_BASE_URL:-}" && -z "${HERMES_BASE_URL:-}" ]]; then export HERMES_BASE_URL="$AGENT_BASE_URL"; fi
      if [[ -n "${AGENT_MODEL:-}" && -z "${HERMES_MODEL:-}" ]]; then export HERMES_MODEL="$AGENT_MODEL"; fi
      ;;
  esac
}

validate_agent_env() {
  local normalized="$1"
  case "$normalized" in
    codex)
      [[ -n "${CODEX_TOKEN:-${OPENAI_API_KEY:-}}" ]] || fail "Missing AGENT_TOKEN, CODEX_TOKEN, or OPENAI_API_KEY."
      [[ -n "${CODEX_API_URL:-${OPENAI_BASE_URL:-}}" ]] || fail "Missing AGENT_BASE_URL, CODEX_API_URL, or OPENAI_BASE_URL."
      ;;
    claudecode)
      [[ -n "${CLAUDE_TOKEN:-${CLAUDE_CLIENT_TOKEN:-}}" ]] || fail "Missing AGENT_TOKEN, CLAUDE_TOKEN, or CLAUDE_CLIENT_TOKEN."
      [[ -n "${CLAUDE_API_URL:-}" ]] || fail "Missing AGENT_BASE_URL or CLAUDE_API_URL."
      ;;
    openclaw)
      [[ -n "${OPENCLAW_TOKEN:-}" ]] || fail "Missing AGENT_TOKEN or OPENCLAW_TOKEN."
      [[ -n "${OPENCLAW_BASE_URL:-${OPENCLAW_API_URL:-}}" ]] || fail "Missing AGENT_BASE_URL, OPENCLAW_BASE_URL, or OPENCLAW_API_URL."
      ;;
    hermes)
      [[ -n "${HERMES_API_KEY:-${HERMES_TOKEN:-${OPENAI_API_KEY:-}}}" ]] || fail "Missing AGENT_TOKEN, HERMES_API_KEY, HERMES_TOKEN, or OPENAI_API_KEY."
      [[ -n "${HERMES_BASE_URL:-${OPENAI_BASE_URL:-}}" ]] || fail "Missing AGENT_BASE_URL, HERMES_BASE_URL, or OPENAI_BASE_URL."
      ;;
    codexplusplus)
      ;;
  esac
}

download_source() {
  if [[ -n "$LOCAL_SOURCE" ]]; then
    [[ -d "$LOCAL_SOURCE" ]] || fail "Local source not found: $LOCAL_SOURCE"
    printf "%s" "$LOCAL_SOURCE"
    return 0
  fi

  local tmp_dir archive url ok
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/bootstrap.tar.gz"
  info "Downloading agent bootstrap assets from $BOOTSTRAP_REPO@$BOOTSTRAP_REF" >&2
  ok=0
  for url in \
    "https://codeload.github.com/${BOOTSTRAP_REPO}/tar.gz/refs/heads/${BOOTSTRAP_REF}" \
    "https://codeload.github.com/${BOOTSTRAP_REPO}/tar.gz/refs/tags/${BOOTSTRAP_REF}" \
    "https://github.com/${BOOTSTRAP_REPO}/archive/${BOOTSTRAP_REF}.tar.gz"; do
    if command -v curl >/dev/null 2>&1; then
      curl --retry 3 --retry-delay 1 -fsSL "$url" -o "$archive" || continue
    elif command -v wget >/dev/null 2>&1; then
      wget -qO "$archive" "$url" || continue
    else
      fail "curl or wget is required"
    fi
    if tar -tzf "$archive" >/dev/null 2>&1; then
      ok=1
      break
    fi
  done
  if [[ "$ok" != "1" ]]; then
    fail "Downloaded archive is not a valid gzip tarball from $BOOTSTRAP_REPO@$BOOTSTRAP_REF"
  fi
  tar -xzf "$archive" -C "$tmp_dir" --strip-components=1
  printf "%s" "$tmp_dir"
}

main() {
  printf "\n%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  printf "%b|%b %bAgent Bootstrap%b                                 %b|%b\n" "$CYAN" "$NC" "$BOLD" "$NC" "$CYAN" "$NC"
  printf "%b|%b codex / claudecode / openclaw / hermes        %b|%b\n" "$CYAN" "$NC" "$CYAN" "$NC"
  printf "%b+--------------------------------------------------+%b\n\n" "$CYAN" "$NC"

  local passthrough=()
  if [[ -z "$AGENT" && $# -gt 0 ]]; then
    case "${1:-}" in
      codex|openai-codex|claude|claudecode|claude-code|openclaw|claw|hermes|hermes-agent|codexplusplus|codex-plus-plus|codex++|cpp)
        AGENT="$1"
        shift
        ;;
    esac
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --local) LOCAL_SOURCE="${2:?missing local dir}"; shift 2 ;;
      --repo) BOOTSTRAP_REPO="${2:?missing repo}"; shift 2 ;;
      --ref) BOOTSTRAP_REF="${2:?missing ref}"; shift 2 ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if [[ -z "$AGENT" ]]; then
          case "$1" in
            codex|openai-codex|claude|claudecode|claude-code|openclaw|claw|hermes|hermes-agent|codexplusplus|codex-plus-plus|codex++|cpp)
              AGENT="$1"
              shift
              continue
              ;;
          esac
        fi
        passthrough+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "$AGENT" ]]; then
    usage
    fail "Missing AGENT. Set AGENT=codex, AGENT=claudecode, AGENT=openclaw, AGENT=hermes, or AGENT=codexplusplus."
  fi

  local normalized source_dir installer
  normalized="$(normalize_agent "$AGENT")" || fail "Unknown agent: $AGENT"
  prepare_agent_env "$normalized"
  validate_agent_env "$normalized"
  source_dir="$(download_source)"
  installer="$source_dir/agents/$normalized/install.sh"

  [[ -f "$installer" ]] || fail "Installer not found: $installer"
  ok "Selected agent: $normalized"
  if [[ "$normalized" == "codex" ]]; then
    if ((${#passthrough[@]})); then
      bash "$installer" --local "$source_dir" "${passthrough[@]}"
    else
      bash "$installer" --local "$source_dir"
    fi
  else
    if ((${#passthrough[@]})); then
      bash "$installer" "${passthrough[@]}"
    else
      bash "$installer"
    fi
  fi
}

main "$@"
