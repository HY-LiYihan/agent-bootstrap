#!/usr/bin/env bash
# Minimal stable Codex entrypoint.
# Downloads this repo at a fixed ref and runs the Codex-only installer.

set -euo pipefail
IFS=$'\n\t'

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-HY-LiYihan/agent-bootstrap}"
BOOTSTRAP_REF="${BOOTSTRAP_REF:-stable}"
GITHUB_PROXY_PREFIXES="${BOOTSTRAP_GITHUB_PROXY_PREFIXES:-${CODEX_GITHUB_PROXY_PREFIXES:-https://gh-proxy.com/ https://ghproxy.com/}}"
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
Codex Stable Bootstrap

Usage:
  CODEX_TOKEN="YOUR_TOKEN" CODEX_API_URL="YOUR_BASE_URL" bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.sh)"

Options:
  --repo OWNER/REPO    GitHub repo to download from (default: ${BOOTSTRAP_REPO})
  --ref REF            Git ref/tag/branch to download from (default: ${BOOTSTRAP_REF})
  --local DIR          Use a local checkout instead of downloading
  -h, --help           Show this help

Environment:
  BOOTSTRAP_GITHUB_PROXY_PREFIXES  Space-separated GitHub proxy prefixes for restricted networks

All other options pass through to agents/codex/install.sh, for example:
  --dry-run --skip-codex-install --skip-shell-rc --skip-smoke-test --no-sync-provider-history
USAGE
}

download_source() {
  if [[ -n "$LOCAL_SOURCE" ]]; then
    [[ -d "$LOCAL_SOURCE" ]] || fail "Local source not found: $LOCAL_SOURCE"
    printf "%s" "$LOCAL_SOURCE"
    return 0
  fi

  local tmp_dir archive url ok source_url proxy
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/bootstrap.tar.gz"
  info "Downloading Codex bootstrap assets from $BOOTSTRAP_REPO@$BOOTSTRAP_REF" >&2
  ok=0
  for source_url in \
    "https://codeload.github.com/${BOOTSTRAP_REPO}/tar.gz/refs/heads/${BOOTSTRAP_REF}" \
    "https://codeload.github.com/${BOOTSTRAP_REPO}/tar.gz/refs/tags/${BOOTSTRAP_REF}" \
    "https://github.com/${BOOTSTRAP_REPO}/archive/${BOOTSTRAP_REF}.tar.gz"; do
    for proxy in "" $GITHUB_PROXY_PREFIXES; do
      url="${proxy}${source_url}"
      if command -v curl >/dev/null 2>&1; then
        curl --retry 3 --retry-delay 1 -fsSL "$url" -o "$archive" || continue
      elif command -v wget >/dev/null 2>&1; then
        wget -qO "$archive" "$url" || continue
      else
        fail "curl or wget is required"
      fi
      if tar -tzf "$archive" >/dev/null 2>&1; then
        ok=1
        break 2
      fi
    done
  done
  if [[ "$ok" != "1" ]]; then
    fail "Downloaded archive is not a valid gzip tarball from $BOOTSTRAP_REPO@$BOOTSTRAP_REF"
  fi
  tar -xzf "$archive" -C "$tmp_dir" --strip-components=1
  printf "%s" "$tmp_dir"
}

main() {
  printf "\n%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  printf "%b|%b %bCodex Stable Bootstrap%b                         %b|%b\n" "$CYAN" "$NC" "$BOLD" "$NC" "$CYAN" "$NC"
  printf "%b|%b install + backup + API env setup               %b|%b\n" "$CYAN" "$NC" "$CYAN" "$NC"
  printf "%b+--------------------------------------------------+%b\n\n" "$CYAN" "$NC"

  local passthrough=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) BOOTSTRAP_REPO="${2:?missing repo}"; shift 2 ;;
      --ref) BOOTSTRAP_REF="${2:?missing ref}"; shift 2 ;;
      --local) LOCAL_SOURCE="${2:?missing local dir}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) passthrough+=("$1"); shift ;;
    esac
  done

  local source_dir installer
  source_dir="$(download_source)"
  installer="$source_dir/agents/codex/install.sh"
  [[ -f "$installer" ]] || fail "Codex installer not found: $installer"

  ok "Selected stable agent: codex"
  if ((${#passthrough[@]})); then
    bash "$installer" --local "$source_dir" "${passthrough[@]}"
  else
    bash "$installer" --local "$source_dir"
  fi
}

main "$@"
