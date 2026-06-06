#!/usr/bin/env bash
# Codex Bootstrap
# Safe-ish GitHub curl entrypoint for installing Codex and wiring API env.

set -euo pipefail
IFS=$'\n\t'

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-HY-LiYihan/agent-bootstrap}"
BOOTSTRAP_REF="${BOOTSTRAP_REF:-stable}"
BOOTSTRAP_PROFILE="${CODEX_PROFILE:-default}"
GITHUB_PROXY_PREFIXES="${BOOTSTRAP_GITHUB_PROXY_PREFIXES:-${CODEX_GITHUB_PROXY_PREFIXES:-https://gh-proxy.com/ https://ghproxy.com/}}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="$CODEX_HOME/config.toml"
PRIVATE_ENV_FILE="${CODEX_PRIVATE_ENV_FILE:-$CODEX_HOME/private.env}"
API_BASE_URL="${CODEX_API_URL:-${OPENAI_BASE_URL:-}}"
API_KEY="${CODEX_TOKEN:-${OPENAI_API_KEY:-}}"
PROVIDER_ID="custom"
PROVIDER_ENV_KEY="${CODEX_PROVIDER_ENV_KEY:-CODEX_API_KEY}"
MODEL="${CODEX_MODEL:-gpt-5.5}"
REASONING_EFFORT="${CODEX_REASONING_EFFORT:-high}"
MODEL_VERBOSITY="${CODEX_MODEL_VERBOSITY:-medium}"
REASONING_SUMMARY="${CODEX_REASONING_SUMMARY:-auto}"
WEB_SEARCH="${CODEX_WEB_SEARCH:-live}"
PROJECT_DOC_MAX_BYTES="${CODEX_PROJECT_DOC_MAX_BYTES:-65536}"
AGENTS_MAX_THREADS="${CODEX_AGENTS_MAX_THREADS:-10}"
AGENTS_MAX_DEPTH="${CODEX_AGENTS_MAX_DEPTH:-1}"
AGENTS_JOB_MAX_RUNTIME_SECONDS="${CODEX_AGENTS_JOB_MAX_RUNTIME_SECONDS:-1800}"
REQUEST_MAX_RETRIES="${CODEX_REQUEST_MAX_RETRIES:-4}"
STREAM_MAX_RETRIES="${CODEX_STREAM_MAX_RETRIES:-5}"
STREAM_IDLE_TIMEOUT_MS="${CODEX_STREAM_IDLE_TIMEOUT_MS:-300000}"
SECURITY_PROFILE="${CODEX_SECURITY_PROFILE:-max}"
PROJECT_DIR="${CODEX_PROJECT_DIR:-$PWD}"
NPM_REGISTRY="${CODEX_NPM_REGISTRY:-https://registry.npmmirror.com}"
INSTALL_NODE="${CODEX_INSTALL_NODE:-1}"
NODE_VERSION="${CODEX_NODE_VERSION:-24.12.0}"
BUN_VERSION="${CODEX_BUN_VERSION:-1.2.1}"
NVM_NODEJS_ORG_MIRROR="${CODEX_NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node/}"
NVM_NPM_MIRROR="${CODEX_NVM_NPM_MIRROR:-https://npmmirror.com/mirrors/npm/}"
LOCAL_SOURCE=""
DRY_RUN=0
YES=0
FORCE=0
SKIP_CODEX_INSTALL=0
SKIP_SHELL_RC=0
INSTALL_BUN=1
SYNC_PROVIDER_HISTORY="${CODEX_SYNC_PROVIDER_HISTORY:-0}"
INSTALL_BACKUP="${CODEX_INSTALL_BACKUP:-1}"
INSTALL_BACKUP_DIR="${CODEX_INSTALL_BACKUP_DIR:-}"
WRITE_MANAGED_CONFIG="${CODEX_WRITE_MANAGED_CONFIG:-0}"
INSTALL_TEMPLATES="${CODEX_INSTALL_TEMPLATES:-0}"
CLEANUP_BACKUPS=0
RESTORE_FROM=""
OS_ID=""
OS_NAME=""
ARCH_NAME=""
SHELL_NAME=""
SHELL_RC=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
  printf "\n"
  printf "%b╔══════════════════════════════════════════════════╗%b\n" "$CYAN" "$NC"
  printf "%b║%b %bCodex Bootstrap%b                                  %b║%b\n" "$CYAN" "$NC" "$BOLD" "$NC" "$CYAN" "$NC"
  printf "%b║%b install + backup + API env, config-preserving  %b║%b\n" "$CYAN" "$NC" "$CYAN" "$NC"
  printf "%b╚══════════════════════════════════════════════════╝%b\n\n" "$CYAN" "$NC"
}

log_step() { printf "\n%b▶ %s%b %b%s%b\n" "$MAGENTA" "$1" "$NC" "$BOLD" "$2" "$NC"; }
log_ok() { printf "%b[OK]%b %s\n" "$GREEN" "$NC" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
log_info() { printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$1"; }
log_keep() { printf "%b[KEEP]%b %s\n" "$CYAN" "$NC" "$1"; }
fail() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2; exit 1; }

usage() {
  cat <<USAGE
Codex Bootstrap

Usage:
  CODEX_TOKEN="..." CODEX_API_URL="https://gateway.example.com/v1" bash -c "\$(curl -fsSL <install-url>)"

Options:
  --profile NAME       Profile to apply when --write-managed-config is used (default: ${BOOTSTRAP_PROFILE})
  --project DIR        Project directory for optional AGENTS.md generation (default: current directory)
  --repo OWNER/REPO    GitHub repo to download templates from (default: ${BOOTSTRAP_REPO})
  --ref REF            Git ref/tag/branch to download templates from (default: ${BOOTSTRAP_REF})
  --local DIR          Use a local checkout instead of downloading from GitHub
  --dry-run            Show intended changes without writing files or installing packages
  --yes                Do not prompt before high-impact actions
  --force              Allow reinstalling Codex and overwriting managed files
  --skip-codex-install Do not install or update @openai/codex
  --skip-shell-rc      Do not add source line to shell startup file
  --no-install-backup  Do not create a pre-install restore snapshot
  --backup-dir DIR     Write the pre-install restore snapshot to DIR
  --restore DIR        Restore files from a previous install backup and exit
  --cleanup-backups    Delete ~/.codex.backup.* backup folders and exit
  --write-managed-config      Write the legacy managed custom-provider config (default: off)
  --install-templates         Install templates/default.rules and project AGENTS.md (default: off)
  --sync-provider-history     Sync old Codex sessions to the selected model_provider (default: off)
  --no-sync-provider-history  Skip provider history sync
  --no-bun             Do not install Bun automatically; use npm if available
  --no-node            Do not install Node.js with NVM when npm is missing
  -h, --help           Show this help

Environment:
  CODEX_TOKEN or OPENAI_API_KEY       API key written to ~/.codex/private.env
  CODEX_API_URL or OPENAI_BASE_URL    API base URL written to ~/.codex/private.env
  CODEX_PROVIDER_ENV_KEY              Provider env key (default: ${PROVIDER_ENV_KEY})
  CODEX_MODEL                         Default model (default: ${MODEL})
  CODEX_REASONING_EFFORT              Reasoning effort (default: ${REASONING_EFFORT})
  CODEX_MODEL_VERBOSITY               Model verbosity: low, medium, or high (default: ${MODEL_VERBOSITY})
  CODEX_REASONING_SUMMARY             Reasoning summary: auto, concise, detailed, or none (default: ${REASONING_SUMMARY})
  CODEX_WEB_SEARCH                    Web search mode: live, cached, or disabled (default: ${WEB_SEARCH})
  CODEX_PROJECT_DOC_MAX_BYTES         Max AGENTS.md bytes to include (default: ${PROJECT_DOC_MAX_BYTES})
  CODEX_AGENTS_MAX_THREADS            Max simultaneously open subagent threads (default: ${AGENTS_MAX_THREADS})
  CODEX_AGENTS_MAX_DEPTH              Max subagent nesting depth (default: ${AGENTS_MAX_DEPTH})
  CODEX_AGENTS_JOB_MAX_RUNTIME_SECONDS Max batch subagent job runtime seconds (default: ${AGENTS_JOB_MAX_RUNTIME_SECONDS})
  CODEX_REQUEST_MAX_RETRIES           Provider request retries (default: ${REQUEST_MAX_RETRIES})
  CODEX_STREAM_MAX_RETRIES            Provider stream retries (default: ${STREAM_MAX_RETRIES})
  CODEX_STREAM_IDLE_TIMEOUT_MS        Provider stream idle timeout ms (default: ${STREAM_IDLE_TIMEOUT_MS})
  CODEX_SECURITY_PROFILE              max or safe (default: ${SECURITY_PROFILE})
  CODEX_SYNC_PROVIDER_HISTORY         1 or 0 (default: ${SYNC_PROVIDER_HISTORY})
  CODEX_INSTALL_BACKUP                1 or 0; backup the whole ~/.codex folder (default: ${INSTALL_BACKUP})
  CODEX_INSTALL_BACKUP_DIR            Optional explicit backup directory
  CODEX_WRITE_MANAGED_CONFIG          1 or 0; write legacy managed config (default: ${WRITE_MANAGED_CONFIG})
  CODEX_INSTALL_TEMPLATES             1 or 0; install rules/AGENTS templates (default: ${INSTALL_TEMPLATES})
  CODEX_NPM_REGISTRY                  npm fallback registry (default: ${NPM_REGISTRY})
  CODEX_INSTALL_NODE                  1 or 0; install Node.js with NVM if npm is missing (default: ${INSTALL_NODE})
  CODEX_NODE_VERSION                  Node.js version for NVM fallback (default: ${NODE_VERSION})
  CODEX_BUN_VERSION                   Bun mirror fallback version (default: ${BUN_VERSION})
  CODEX_NVM_NODEJS_ORG_MIRROR         NVM Node.js mirror (default: ${NVM_NODEJS_ORG_MIRROR})
  CODEX_NVM_NPM_MIRROR                NVM npm mirror (default: ${NVM_NPM_MIRROR})
  BOOTSTRAP_GITHUB_PROXY_PREFIXES     Space-separated GitHub proxy prefixes for restricted networks
  CODEX_PROFILE                       Profile name (default: default)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) BOOTSTRAP_PROFILE="${2:?missing profile}"; shift 2 ;;
    --project) PROJECT_DIR="${2:?missing project dir}"; shift 2 ;;
    --repo) BOOTSTRAP_REPO="${2:?missing repo}"; shift 2 ;;
    --ref) BOOTSTRAP_REF="${2:?missing ref}"; shift 2 ;;
    --local) LOCAL_SOURCE="${2:?missing local dir}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) YES=1; shift ;;
    --force) FORCE=1; shift ;;
    --skip-codex-install) SKIP_CODEX_INSTALL=1; shift ;;
    --skip-shell-rc) SKIP_SHELL_RC=1; shift ;;
    --no-install-backup) INSTALL_BACKUP=0; shift ;;
    --backup-dir) INSTALL_BACKUP_DIR="${2:?missing backup dir}"; shift 2 ;;
    --restore) RESTORE_FROM="${2:?missing backup dir}"; shift 2 ;;
    --cleanup-backups) CLEANUP_BACKUPS=1; shift ;;
    --write-managed-config) WRITE_MANAGED_CONFIG=1; shift ;;
    --install-templates) INSTALL_TEMPLATES=1; shift ;;
    --sync-provider-history) SYNC_PROVIDER_HISTORY=1; shift ;;
    --no-sync-provider-history) SYNC_PROVIDER_HISTORY=0; shift ;;
    --no-bun) INSTALL_BUN=0; shift ;;
    --no-node) INSTALL_NODE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

command_exists() { command -v "$1" >/dev/null 2>&1; }
validate_env_key() {
  [[ "$PROVIDER_ENV_KEY" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || fail "Invalid CODEX_PROVIDER_ENV_KEY: $PROVIDER_ENV_KEY"
}

validate_required_inputs() {
  [[ -n "$API_KEY" ]] || fail "Missing CODEX_TOKEN or OPENAI_API_KEY"
  [[ -n "$API_BASE_URL" ]] || fail "Missing CODEX_API_URL or OPENAI_BASE_URL"
  case "$MODEL_VERBOSITY" in
    low|medium|high) ;;
    *) fail "Invalid CODEX_MODEL_VERBOSITY: $MODEL_VERBOSITY. Use low, medium, or high." ;;
  esac
  case "$REASONING_SUMMARY" in
    auto|concise|detailed|none) ;;
    *) fail "Invalid CODEX_REASONING_SUMMARY: $REASONING_SUMMARY. Use auto, concise, detailed, or none." ;;
  esac
  case "$WEB_SEARCH" in
    live|cached|disabled) ;;
    *) fail "Invalid CODEX_WEB_SEARCH: $WEB_SEARCH. Use live, cached, or disabled." ;;
  esac
  [[ "$PROJECT_DOC_MAX_BYTES" =~ ^[0-9]+$ ]] || fail "Invalid CODEX_PROJECT_DOC_MAX_BYTES: $PROJECT_DOC_MAX_BYTES"
  [[ "$AGENTS_MAX_THREADS" =~ ^[0-9]+$ ]] || fail "Invalid CODEX_AGENTS_MAX_THREADS: $AGENTS_MAX_THREADS"
  [[ "$AGENTS_MAX_DEPTH" =~ ^[0-9]+$ ]] || fail "Invalid CODEX_AGENTS_MAX_DEPTH: $AGENTS_MAX_DEPTH"
  [[ "$AGENTS_JOB_MAX_RUNTIME_SECONDS" =~ ^[0-9]+$ ]] || fail "Invalid CODEX_AGENTS_JOB_MAX_RUNTIME_SECONDS: $AGENTS_JOB_MAX_RUNTIME_SECONDS"
  [[ "$REQUEST_MAX_RETRIES" =~ ^[0-9]+$ ]] || fail "Invalid CODEX_REQUEST_MAX_RETRIES: $REQUEST_MAX_RETRIES"
  [[ "$STREAM_MAX_RETRIES" =~ ^[0-9]+$ ]] || fail "Invalid CODEX_STREAM_MAX_RETRIES: $STREAM_MAX_RETRIES"
  [[ "$STREAM_IDLE_TIMEOUT_MS" =~ ^[0-9]+$ ]] || fail "Invalid CODEX_STREAM_IDLE_TIMEOUT_MS: $STREAM_IDLE_TIMEOUT_MS"
  case "$SECURITY_PROFILE" in
    max|full|full-auto|danger) SECURITY_PROFILE="max" ;;
    safe|official|default) SECURITY_PROFILE="safe" ;;
    *) fail "Invalid CODEX_SECURITY_PROFILE: $SECURITY_PROFILE. Use max or safe." ;;
  esac
  case "$SYNC_PROVIDER_HISTORY" in
    1|true|yes|on) SYNC_PROVIDER_HISTORY=1 ;;
    0|false|no|off) SYNC_PROVIDER_HISTORY=0 ;;
    *) fail "Invalid CODEX_SYNC_PROVIDER_HISTORY: $SYNC_PROVIDER_HISTORY. Use 1 or 0." ;;
  esac
  case "$INSTALL_NODE" in
    1|true|yes|on) INSTALL_NODE=1 ;;
    0|false|no|off) INSTALL_NODE=0 ;;
    *) fail "Invalid CODEX_INSTALL_NODE: $INSTALL_NODE. Use 1 or 0." ;;
  esac
  case "$INSTALL_BACKUP" in
    1|true|yes|on) INSTALL_BACKUP=1 ;;
    0|false|no|off) INSTALL_BACKUP=0 ;;
    *) fail "Invalid CODEX_INSTALL_BACKUP: $INSTALL_BACKUP. Use 1 or 0." ;;
  esac
  case "$WRITE_MANAGED_CONFIG" in
    1|true|yes|on) WRITE_MANAGED_CONFIG=1 ;;
    0|false|no|off) WRITE_MANAGED_CONFIG=0 ;;
    *) fail "Invalid CODEX_WRITE_MANAGED_CONFIG: $WRITE_MANAGED_CONFIG. Use 1 or 0." ;;
  esac
  case "$INSTALL_TEMPLATES" in
    1|true|yes|on) INSTALL_TEMPLATES=1 ;;
    0|false|no|off) INSTALL_TEMPLATES=0 ;;
    *) fail "Invalid CODEX_INSTALL_TEMPLATES: $INSTALL_TEMPLATES. Use 1 or 0." ;;
  esac
}

detect_platform() {
  local kernel
  kernel="$(uname -s 2>/dev/null || printf unknown)"
  ARCH_NAME="$(uname -m 2>/dev/null || printf unknown)"

  case "$kernel" in
    Darwin)
      OS_ID="macos"
      OS_NAME="macOS"
      ;;
    Linux)
      OS_ID="linux"
      OS_NAME="Linux"
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_NAME="${PRETTY_NAME:-${NAME:-Linux}}"
      fi
      ;;
    *)
      fail "Unsupported OS for install.sh: $kernel. Use install.ps1 on Windows."
      ;;
  esac

  if [[ "${SHELL:-}" == *zsh* ]]; then
    SHELL_NAME="zsh"
    SHELL_RC="$HOME/.zshrc"
  elif [[ "${SHELL:-}" == *bash* ]]; then
    SHELL_NAME="bash"
    if [[ "$OS_ID" == "macos" ]]; then
      SHELL_RC="$HOME/.bash_profile"
    else
      SHELL_RC="$HOME/.bashrc"
    fi
  else
    SHELL_NAME="${SHELL##*/}"
    SHELL_RC="$HOME/.profile"
  fi
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN:"
    printf " %q" "$@"
    printf "\n"
  else
    "$@"
  fi
}

toml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf "%s" "$value"
}

confirm() {
  local message="$1"
  if [[ "$YES" == "1" || "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  printf "%s [y/N] " "$message"
  read -r reply
  [[ "$reply" == "y" || "$reply" == "Y" || "$reply" == "yes" || "$reply" == "YES" ]]
}

detect_shell_rc() {
  if [[ -n "$SHELL_RC" ]]; then
    printf "%s" "$SHELL_RC"
  elif [[ "${SHELL:-}" == *zsh* ]]; then
    printf "%s/.zshrc" "$HOME"
  else
    printf "%s/.bashrc" "$HOME"
  fi
}

mask_secret() {
  local value="$1"
  if [[ ${#value} -le 8 ]]; then
    printf "<hidden>"
  else
    printf "%s...%s" "${value:0:4}" "${value: -4}"
  fi
}

mask_url() {
  local value="$1"
  if [[ -z "$value" ]]; then
    printf "<missing>"
  else
    printf "<configured>"
  fi
}

load_profile() {
  local source_dir="$1"
  local profile_file="$source_dir/profiles/$BOOTSTRAP_PROFILE.env"
  if [[ -f "$profile_file" ]]; then
    # shellcheck disable=SC1090
    source "$profile_file"
    MODEL="${CODEX_MODEL:-$MODEL}"
    REASONING_EFFORT="${CODEX_REASONING_EFFORT:-$REASONING_EFFORT}"
    MODEL_VERBOSITY="${CODEX_MODEL_VERBOSITY:-$MODEL_VERBOSITY}"
    REASONING_SUMMARY="${CODEX_REASONING_SUMMARY:-$REASONING_SUMMARY}"
    WEB_SEARCH="${CODEX_WEB_SEARCH:-$WEB_SEARCH}"
    PROJECT_DOC_MAX_BYTES="${CODEX_PROJECT_DOC_MAX_BYTES:-$PROJECT_DOC_MAX_BYTES}"
    AGENTS_MAX_THREADS="${CODEX_AGENTS_MAX_THREADS:-$AGENTS_MAX_THREADS}"
    AGENTS_MAX_DEPTH="${CODEX_AGENTS_MAX_DEPTH:-$AGENTS_MAX_DEPTH}"
    AGENTS_JOB_MAX_RUNTIME_SECONDS="${CODEX_AGENTS_JOB_MAX_RUNTIME_SECONDS:-$AGENTS_JOB_MAX_RUNTIME_SECONDS}"
    REQUEST_MAX_RETRIES="${CODEX_REQUEST_MAX_RETRIES:-$REQUEST_MAX_RETRIES}"
    STREAM_MAX_RETRIES="${CODEX_STREAM_MAX_RETRIES:-$STREAM_MAX_RETRIES}"
    STREAM_IDLE_TIMEOUT_MS="${CODEX_STREAM_IDLE_TIMEOUT_MS:-$STREAM_IDLE_TIMEOUT_MS}"
    SECURITY_PROFILE="${CODEX_SECURITY_PROFILE:-$SECURITY_PROFILE}"
    log_ok "Loaded profile: $BOOTSTRAP_PROFILE"
  else
    log_warn "Profile not found: $BOOTSTRAP_PROFILE; using built-in defaults"
  fi
}

download_source() {
  if [[ -n "$LOCAL_SOURCE" ]]; then
    [[ -d "$LOCAL_SOURCE" ]] || fail "Local source not found: $LOCAL_SOURCE"
    printf "%s" "$LOCAL_SOURCE"
    return 0
  fi

  local tmp_dir archive source_url url proxy ok
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/bootstrap.tar.gz"
  log_info "Downloading bootstrap assets from $BOOTSTRAP_REPO@$BOOTSTRAP_REF" >&2
  ok=0
  for source_url in \
    "https://codeload.github.com/${BOOTSTRAP_REPO}/tar.gz/refs/heads/${BOOTSTRAP_REF}" \
    "https://codeload.github.com/${BOOTSTRAP_REPO}/tar.gz/refs/tags/${BOOTSTRAP_REF}" \
    "https://github.com/${BOOTSTRAP_REPO}/archive/${BOOTSTRAP_REF}.tar.gz"; do
    for proxy in "" $GITHUB_PROXY_PREFIXES; do
      url="${proxy}${source_url}"
      if command_exists curl; then
        curl --retry 3 --retry-delay 1 -fsSL "$url" -o "$archive" || continue
      elif command_exists wget; then
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

download_file() {
  local url="$1"
  local dest="$2"
  if command_exists curl; then
    curl --retry 3 --retry-delay 1 -fsSL --connect-timeout 15 "$url" -o "$dest"
  elif command_exists wget; then
    wget -qO "$dest" "$url"
  else
    fail "curl or wget is required"
  fi
}

download_to_stdout() {
  local url="$1"
  if command_exists curl; then
    curl --retry 3 --retry-delay 1 -fsSL --connect-timeout 15 "$url"
  elif command_exists wget; then
    wget -qO- "$url"
  else
    fail "curl or wget is required"
  fi
}

append_shell_line_once() {
  local shell_rc="$1"
  local line="$2"
  touch "$shell_rc"
  if ! grep -Fq "$line" "$shell_rc"; then
    printf "%s\n" "$line" >> "$shell_rc"
  fi
}

ensure_bun() {
  [[ "$INSTALL_BUN" == "1" ]] || return 1
  if command_exists bun; then
    log_ok "Bun found: $(bun --version)"
    return 0
  fi

  log_info "Bun is missing; installing Bun runtime"
  if [[ "$DRY_RUN" == "1" ]]; then
    run bash -c 'curl -fsSL https://bun.sh/install | bash'
    log_info "If the official Bun installer is unreachable, mirror fallback uses npmmirror/gh-proxy zip packages"
    run mkdir -p "$HOME/.bun/bin"
    return 0
  fi

  if download_to_stdout https://bun.sh/install | bash; then
    log_ok "Bun installed with official installer"
  else
    log_warn "Official Bun installer failed; trying mirror zip fallback"
    install_bun_from_mirror || log_warn "Bun mirror install failed; npm fallback may still work"
  fi

  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  command_exists bun || return 1
}

install_bun_from_mirror() {
  command_exists unzip || {
    log_warn "unzip not found; cannot unpack Bun mirror zip"
    return 1
  }

  local arch os_type bun_pkg tmp_dir tmp_zip bun_install_dir mirror_url found_bun
  arch="$(uname -m 2>/dev/null || printf unknown)"
  os_type="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  bun_install_dir="$HOME/.bun"
  tmp_dir="$(mktemp -d)"
  tmp_zip="$tmp_dir/bun.zip"

  case "$os_type:$arch" in
    darwin:arm64) bun_pkg="bun-darwin-aarch64.zip" ;;
    darwin:x86_64|darwin:amd64) bun_pkg="bun-darwin-x64.zip" ;;
    linux:aarch64|linux:arm64) bun_pkg="bun-linux-aarch64.zip" ;;
    linux:x86_64|linux:amd64) bun_pkg="bun-linux-x64.zip" ;;
    *)
      rm -rf "$tmp_dir"
      log_warn "Unsupported Bun mirror package for $os_type/$arch"
      return 1
      ;;
  esac

  local mirrors=(
    "https://registry.npmmirror.com/-/binary/bun/bun-v${BUN_VERSION}/${bun_pkg}"
    "https://gh-proxy.com/https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/${bun_pkg}"
    "https://ghproxy.com/https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/${bun_pkg}"
  )

  for mirror_url in "${mirrors[@]}"; do
    log_info "Trying Bun mirror: $mirror_url"
    if download_file "$mirror_url" "$tmp_zip" && unzip -o -q "$tmp_zip" -d "$tmp_dir/extract"; then
      found_bun="$(find "$tmp_dir/extract" -name bun -type f | head -n 1)"
      if [[ -n "$found_bun" ]]; then
        mkdir -p "$bun_install_dir/bin"
        cp "$found_bun" "$bun_install_dir/bin/bun"
        chmod +x "$bun_install_dir/bin/bun"
        rm -rf "$tmp_dir"
        log_ok "Bun installed from mirror"
        return 0
      fi
    fi
  done

  rm -rf "$tmp_dir"
  return 1
}

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
    return 0
  fi
  return 1
}

install_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  local shell_rc nvm_url installed
  shell_rc="$(detect_shell_rc)"
  log_info "Installing NVM into $NVM_DIR"

  if [[ "$DRY_RUN" == "1" ]]; then
    run mkdir -p "$NVM_DIR"
    run bash -c "curl --retry 3 --retry-delay 1 -fsSL 'https://github.com/nvm-sh/nvm/archive/v0.40.3.tar.gz' | tar -xz -C '$NVM_DIR' --strip-components=1"
    printf "DRY-RUN: configure NVM mirrors: NVM_NODEJS_ORG_MIRROR=%s NVM_NPM_MIRROR=%s\n" "$NVM_NODEJS_ORG_MIRROR" "$NVM_NPM_MIRROR"
    return 0
  fi

  mkdir -p "$NVM_DIR"
  installed=0
  for nvm_url in \
    "https://github.com/nvm-sh/nvm/archive/v0.40.3.tar.gz" \
    "https://gh-proxy.com/https://github.com/nvm-sh/nvm/archive/v0.40.3.tar.gz" \
    "https://ghproxy.com/https://github.com/nvm-sh/nvm/archive/v0.40.3.tar.gz"; do
    log_info "Trying NVM source: $nvm_url"
    if download_to_stdout "$nvm_url" | tar -xz -C "$NVM_DIR" --strip-components=1; then
      installed=1
      break
    fi
  done
  if [[ "$installed" != "1" ]]; then
    fail "Failed to install NVM from $nvm_url"
  fi

  touch "$shell_rc"
  if ! grep -Fq 'NVM_DIR="$HOME/.nvm"' "$shell_rc"; then
    {
      printf "\n# NVM - Added by Codex Bootstrap\n"
      printf 'export NVM_DIR="$HOME/.nvm"\n'
      printf '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n'
      printf '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"\n'
    } >> "$shell_rc"
  fi
  append_shell_line_once "$shell_rc" "export NVM_NODEJS_ORG_MIRROR=$NVM_NODEJS_ORG_MIRROR"
  append_shell_line_once "$shell_rc" "export NVM_NPM_MIRROR=$NVM_NPM_MIRROR"
  export NVM_NODEJS_ORG_MIRROR
  export NVM_NPM_MIRROR
  log_ok "NVM ready: $NVM_DIR"
}

ensure_npm_available() {
  if command_exists npm; then
    return 0
  fi
  [[ "$INSTALL_NODE" == "1" ]] || fail "npm is required when Bun is unavailable. Install Node.js or rerun without --no-node."

  log_info "npm is missing; preparing Node.js $NODE_VERSION with NVM"
  export NVM_NODEJS_ORG_MIRROR
  export NVM_NPM_MIRROR
  if [[ "$DRY_RUN" == "1" ]]; then
    if ! load_nvm; then
      install_nvm
    fi
    run bash -c "source '$NVM_DIR/nvm.sh' && nvm install '$NODE_VERSION' && nvm use '$NODE_VERSION' && nvm alias default '$NODE_VERSION'"
    return 0
  fi

  if ! load_nvm; then
    install_nvm
    load_nvm || fail "NVM installed but could not be loaded"
  fi

  export NVM_NODEJS_ORG_MIRROR
  export NVM_NPM_MIRROR
  nvm install "$NODE_VERSION"
  nvm use "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"
  command_exists npm || fail "Node.js was installed but npm is still unavailable"
  log_ok "Node.js/npm ready: node $(node --version), npm $(npm --version)"
}

install_codex() {
  if [[ "$SKIP_CODEX_INSTALL" == "1" ]]; then
    log_info "Skipping Codex install"
    return 0
  fi

  if command_exists codex && [[ "$FORCE" != "1" ]]; then
    log_ok "Codex already installed: $(command -v codex)"
    return 0
  fi

  log_step "Codex" "Installing @openai/codex"
  if ensure_bun; then
    if run bun install -g @openai/codex; then
      return 0
    fi
    log_warn "Bun failed to install @openai/codex; falling back to npm"
  fi

  ensure_npm_available
  if run npm install -g @openai/codex; then
    return 0
  fi
  log_warn "npm default registry install failed; retrying with $NPM_REGISTRY"
  run npm install -g @openai/codex --registry="$NPM_REGISTRY"
}

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local backup="$file.backup.$(date +%Y%m%d_%H%M%S)"
  run cp "$file" "$backup"
  log_ok "Backup created: $backup"
}

copy_if_exists() {
  local src="$1"
  local dest="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -p "$src" "$dest"
  fi
}

copy_dir_contents() {
  local src="$1"
  local dest="$2"
  mkdir -p "$dest"
  if command_exists rsync; then
    rsync -a "$src/" "$dest/"
  else
    cp -a "$src/." "$dest/"
  fi
}

create_install_backup() {
  [[ "$INSTALL_BACKUP" == "1" ]] || return 0
  log_step "1/4" "Backup existing Codex home"
  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ -d "$CODEX_HOME" ]]; then
      printf "DRY-RUN: copy %s to %s\n" "$CODEX_HOME" "${INSTALL_BACKUP_DIR:-$HOME/.codex.backup.$(date +%Y%m%d%H%M%S)}"
    else
      printf "DRY-RUN: no existing Codex home to back up: %s\n" "$CODEX_HOME"
    fi
    return 0
  fi

  local backup_dir shell_rc size
  shell_rc="$(detect_shell_rc)"
  if [[ -n "$INSTALL_BACKUP_DIR" ]]; then
    backup_dir="$INSTALL_BACKUP_DIR"
  else
    backup_dir="$HOME/.codex.backup.$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$backup_dir"

  {
    printf "created_at=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "codex_home=%s\n" "$CODEX_HOME"
    printf "shell_rc=%s\n" "$shell_rc"
    printf "restore_hint=%s --restore %s\n" "$0" "$backup_dir"
    printf "cleanup_hint=find \"%s\" -maxdepth 1 -type d -name '.codex.backup.*' -prune -exec rm -rf {} +\n" "$HOME"
  } > "$backup_dir/MANIFEST.txt"

  if [[ -d "$CODEX_HOME" ]]; then
    copy_dir_contents "$CODEX_HOME" "$backup_dir/.codex"
    size="$(du -sh "$backup_dir" 2>/dev/null | awk '{print $1}' || printf unknown)"
    log_ok "Codex home backed up: $backup_dir ($size)"
  else
    log_info "No existing Codex home found; created empty backup marker: $backup_dir"
  fi

  mkdir -p "$CODEX_HOME"
  printf "%s\n" "$backup_dir" > "$CODEX_HOME/.last-install-backup"
  log_info "Restore with: $0 --restore '$backup_dir'"
}

restore_install_backup() {
  local backup_dir="$1"
  [[ -d "$backup_dir" ]] || fail "Restore backup not found: $backup_dir"
  log_step "Restore" "Restore Codex home from $backup_dir"
  if [[ -d "$backup_dir/.codex" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      printf "DRY-RUN: restore %s/.codex to %s\n" "$backup_dir" "$CODEX_HOME"
    else
      mkdir -p "$CODEX_HOME"
      copy_dir_contents "$backup_dir/.codex" "$CODEX_HOME"
      chmod 600 "$PRIVATE_ENV_FILE" 2>/dev/null || true
    fi
  else
    run mkdir -p "$CODEX_HOME" "$CODEX_HOME/rules" "$PROJECT_DIR"
    [[ -f "$backup_dir/codex/config.toml" ]] && run cp "$backup_dir/codex/config.toml" "$CONFIG_FILE"
    [[ -f "$backup_dir/codex/private.env" ]] && run cp "$backup_dir/codex/private.env" "$PRIVATE_ENV_FILE"
    [[ -f "$backup_dir/codex/private.env" && "$DRY_RUN" != "1" ]] && chmod 600 "$PRIVATE_ENV_FILE" 2>/dev/null || true
    [[ -f "$backup_dir/codex/rules/default.rules" ]] && run cp "$backup_dir/codex/rules/default.rules" "$CODEX_HOME/rules/default.rules"
    if [[ -f "$backup_dir/codex/state_5.sqlite" ]]; then
      if [[ "$DRY_RUN" == "1" ]]; then
        run cp "$backup_dir/codex/state_5.sqlite" "$CODEX_HOME/state_5.sqlite"
        run rm -f "$CODEX_HOME/state_5.sqlite-wal" "$CODEX_HOME/state_5.sqlite-shm"
      else
        rm -f "$CODEX_HOME/state_5.sqlite-wal" "$CODEX_HOME/state_5.sqlite-shm"
        cp "$backup_dir/codex/state_5.sqlite" "$CODEX_HOME/state_5.sqlite"
      fi
    fi
    [[ -f "$backup_dir/project/AGENTS.md" ]] && run cp "$backup_dir/project/AGENTS.md" "$PROJECT_DIR/AGENTS.md"
  fi
  log_ok "Restore completed from: $backup_dir"
}

cleanup_backups() {
  log_step "Cleanup" "Delete Codex backup folders"
  local count
  count="$(find "$HOME" -maxdepth 1 -type d -name '.codex.backup.*' -prune 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$count" == "0" ]]; then
    log_info "No ~/.codex.backup.* folders found"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    find "$HOME" -maxdepth 1 -type d -name '.codex.backup.*' -prune -print
    return 0
  fi
  find "$HOME" -maxdepth 1 -type d -name '.codex.backup.*' -prune -exec rm -rf {} +
  log_ok "Deleted $count Codex backup folder(s)"
}

preserve_config_tail() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  awk '
    /^\[marketplaces/ || /^\[plugins/ { preserve = 1 }
    preserve { print }
  ' "$CONFIG_FILE"
}

write_private_env() {
  [[ -n "$API_KEY" ]] || fail "Missing CODEX_TOKEN or OPENAI_API_KEY"
  log_step "3/4" "Configure API environment"
  log_info "Secret file: $PRIVATE_ENV_FILE"
  log_info "Exports: OPENAI_API_KEY, OPENAI_BASE_URL, CODEX_API_KEY, CODEX_API_URL"
  run mkdir -p "$(dirname "$PRIVATE_ENV_FILE")"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN: write API env with key=%s base_url=%s to %s\n" "$(mask_secret "$API_KEY")" "$(mask_url "$API_BASE_URL")" "$PRIVATE_ENV_FILE"
  else
    umask 077
    cat > "$PRIVATE_ENV_FILE" <<ENVEOF
# Managed by agent-bootstrap. Do not commit this file.
export OPENAI_API_KEY="$API_KEY"
export OPENAI_BASE_URL="$API_BASE_URL"
export CODEX_API_KEY="$API_KEY"
export CODEX_API_URL="$API_BASE_URL"
ENVEOF
    if [[ "$PROVIDER_ENV_KEY" != "OPENAI_API_KEY" && "$PROVIDER_ENV_KEY" != "CODEX_API_KEY" ]]; then
      printf 'export %s="%s"\n' "$PROVIDER_ENV_KEY" "$API_KEY" >> "$PRIVATE_ENV_FILE"
    fi
    chmod 600 "$PRIVATE_ENV_FILE"
  fi
  log_ok "Private env ready: $PRIVATE_ENV_FILE"
}

preserve_or_default_config() {
  log_step "4/4" "Preserve Codex configuration"
  run mkdir -p "$CODEX_HOME"
  if [[ -f "$CONFIG_FILE" ]]; then
    log_keep "Existing config.toml found; leaving it unchanged: $CONFIG_FILE"
  else
    log_keep "No config.toml found; leaving it absent so Codex uses official defaults"
  fi
}

write_config() {
  log_step "Managed config" "Write legacy custom-provider config"
  run mkdir -p "$CODEX_HOME"
  backup_file "$CONFIG_FILE"
  local provider_escaped env_key_escaped model_escaped effort_escaped verbosity_escaped summary_escaped web_search_escaped url_escaped
  provider_escaped="$(toml_escape "$PROVIDER_ID")"
  env_key_escaped="$(toml_escape "$PROVIDER_ENV_KEY")"
  model_escaped="$(toml_escape "$MODEL")"
  effort_escaped="$(toml_escape "$REASONING_EFFORT")"
  verbosity_escaped="$(toml_escape "$MODEL_VERBOSITY")"
  summary_escaped="$(toml_escape "$REASONING_SUMMARY")"
  web_search_escaped="$(toml_escape "$WEB_SEARCH")"
  url_escaped="$(toml_escape "$API_BASE_URL")"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN: write %s with model_provider=%s base_url=%s env_key=%s security_profile=%s web_search=%s\n" "$CONFIG_FILE" "$PROVIDER_ID" "$(mask_url "$API_BASE_URL")" "$PROVIDER_ENV_KEY" "$SECURITY_PROFILE" "$WEB_SEARCH"
    return 0
  fi

  local tmp_config preserve_tail
  tmp_config="$(mktemp)"
  preserve_tail="$(preserve_config_tail)"

  if [[ "$SECURITY_PROFILE" == "max" ]]; then
    cat > "$tmp_config" <<TOML
# Managed by agent-bootstrap.
# This intentionally uses a custom provider, matching the simple gateway-oriented Codex setup.
model = "$model_escaped"
model_reasoning_effort = "$effort_escaped"
model_verbosity = "$verbosity_escaped"
model_reasoning_summary = "$summary_escaped"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "$provider_escaped"
web_search = "$web_search_escaped"
project_doc_max_bytes = $PROJECT_DOC_MAX_BYTES
approval_policy = "never"
sandbox_mode = "danger-full-access"

[agents]
max_threads = $AGENTS_MAX_THREADS
max_depth = $AGENTS_MAX_DEPTH
job_max_runtime_seconds = $AGENTS_JOB_MAX_RUNTIME_SECONDS

[model_providers."$provider_escaped"]
name = "$provider_escaped"
base_url = "$url_escaped"
wire_api = "responses"
env_key = "$env_key_escaped"
request_max_retries = $REQUEST_MAX_RETRIES
stream_max_retries = $STREAM_MAX_RETRIES
stream_idle_timeout_ms = $STREAM_IDLE_TIMEOUT_MS
TOML
  else
    cat > "$tmp_config" <<TOML
# Managed by agent-bootstrap.
# Safe profile: leaves high-permission controls at Codex defaults.
model = "$model_escaped"
model_reasoning_effort = "$effort_escaped"
model_verbosity = "$verbosity_escaped"
model_reasoning_summary = "$summary_escaped"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "$provider_escaped"
web_search = "$web_search_escaped"
project_doc_max_bytes = $PROJECT_DOC_MAX_BYTES

[agents]
max_threads = $AGENTS_MAX_THREADS
max_depth = $AGENTS_MAX_DEPTH
job_max_runtime_seconds = $AGENTS_JOB_MAX_RUNTIME_SECONDS

[model_providers."$provider_escaped"]
name = "$provider_escaped"
base_url = "$url_escaped"
wire_api = "responses"
env_key = "$env_key_escaped"
request_max_retries = $REQUEST_MAX_RETRIES
stream_max_retries = $STREAM_MAX_RETRIES
stream_idle_timeout_ms = $STREAM_IDLE_TIMEOUT_MS
TOML
  fi

  if [[ -n "$preserve_tail" ]]; then
    printf "\n%s" "$preserve_tail" >> "$tmp_config"
  fi

  mv "$tmp_config" "$CONFIG_FILE"
}

sync_provider_history() {
  local source_dir="$1"
  [[ "$SYNC_PROVIDER_HISTORY" == "1" ]] || return 0
  log_step "Provider sync" "Sync Codex provider history"

  local sync_script="$source_dir/shared/codex-provider-sync.js"
  if [[ ! -f "$sync_script" ]]; then
    log_warn "Provider sync script not found; skipped"
    return 0
  fi
  if ! command_exists node; then
    log_warn "Node.js not found; skipped provider history sync"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    node "$sync_script" --codex-home "$CODEX_HOME" --provider "$PROVIDER_ID" --dry-run || log_warn "Provider history sync dry-run skipped"
  else
    node "$sync_script" --codex-home "$CODEX_HOME" --provider "$PROVIDER_ID" || log_warn "Provider history sync skipped"
  fi
}

install_rules_and_templates() {
  local source_dir="$1"
  local rules_src="$source_dir/templates/default.rules"
  local agents_src="$source_dir/templates/AGENTS.md"

  if [[ -f "$rules_src" ]]; then
    log_step "Templates" "Install optional rules and project AGENTS.md"
    run mkdir -p "$CODEX_HOME/rules"
    backup_file "$CODEX_HOME/rules/default.rules"
    run cp "$rules_src" "$CODEX_HOME/rules/default.rules"
  fi

  if [[ -f "$agents_src" ]]; then
    log_info "Installing project AGENTS.md into $PROJECT_DIR"
    run mkdir -p "$PROJECT_DIR"
    if [[ -f "$PROJECT_DIR/AGENTS.md" && "$FORCE" != "1" ]]; then
      log_warn "AGENTS.md already exists; keeping it. Use --force to overwrite."
    else
      backup_file "$PROJECT_DIR/AGENTS.md"
      run cp "$agents_src" "$PROJECT_DIR/AGENTS.md"
    fi
  fi
}

setup_shell_rc() {
  [[ "$SKIP_SHELL_RC" == "0" ]] || return 0
  local shell_rc
  shell_rc="$(detect_shell_rc)"
  local source_line="[ -f \"$PRIVATE_ENV_FILE\" ] && source \"$PRIVATE_ENV_FILE\""
  log_info "Ensuring shell loads private env"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN: ensure source line exists in %s\n" "$shell_rc"
    return 0
  fi
  touch "$shell_rc"
  if ! grep -Fq "$source_line" "$shell_rc"; then
    {
      printf "\n# Codex Bootstrap secrets\n"
      printf "%s\n" "$source_line"
    } >> "$shell_rc"
  fi
  log_ok "Shell startup configured: $shell_rc"
}

print_completion() {
  local shell_rc
  shell_rc="$(detect_shell_rc)"
  printf "\n%b╔══════════════════════════════════════════════════╗%b\n" "$GREEN" "$NC"
  printf "%b║%b %bCodex ready%b                                      %b║%b\n" "$GREEN" "$NC" "$BOLD" "$NC" "$GREEN" "$NC"
  printf "%b╚══════════════════════════════════════════════════╝%b\n" "$GREEN" "$NC"
  log_info "Reload shell env with: source $shell_rc"
  log_info "Then try: codex --search"
  log_info "After confirming Codex works, remove install backups with:"
  printf "  %bfind \"%s\" -maxdepth 1 -type d -name '.codex.backup.*' -prune -exec rm -rf {} +%b\n" "$CYAN" "$HOME" "$NC"
}

main() {
  print_banner
  detect_platform
  if [[ "$CLEANUP_BACKUPS" == "1" ]]; then
    cleanup_backups
    return 0
  fi
  if [[ -n "$RESTORE_FROM" ]]; then
    restore_install_backup "$RESTORE_FROM"
    return 0
  fi

  validate_env_key
  validate_required_inputs
  log_step "0/4" "Detect environment"
  log_info "OS: $OS_NAME ($OS_ID/$ARCH_NAME)"
  log_info "Shell: ${SHELL_NAME:-unknown}, rc: $(detect_shell_rc)"
  if command_exists codex; then
    log_ok "Codex installed: $(command -v codex)"
    codex --version 2>/dev/null | sed "s/^/[INFO] Codex version: /" || true
  else
    log_warn "Codex CLI not found; installer will install @openai/codex"
  fi
  if [[ -f "$CONFIG_FILE" ]]; then
    log_keep "Existing config will be preserved: $CONFIG_FILE"
  else
    log_keep "No config found; official Codex defaults will be used"
  fi
  log_info "Install backup: $INSTALL_BACKUP"
  log_info "Managed config: $WRITE_MANAGED_CONFIG"
  log_info "Templates: $INSTALL_TEMPLATES"
  log_info "Provider history sync: $SYNC_PROVIDER_HISTORY"
  log_info "Base URL: $(mask_url "$API_BASE_URL")"
  [[ -n "$API_KEY" ]] && log_info "API key: $(mask_secret "$API_KEY")"

  local source_dir=""
  if [[ "$WRITE_MANAGED_CONFIG" == "1" || "$INSTALL_TEMPLATES" == "1" || "$SYNC_PROVIDER_HISTORY" == "1" ]]; then
    log_step "Assets" "Load optional bootstrap assets"
    source_dir="$(download_source)"
    [[ "$WRITE_MANAGED_CONFIG" == "1" ]] && load_profile "$source_dir"
  fi

  create_install_backup
  log_step "2/4" "Install or verify Codex CLI"
  install_codex
  write_private_env
  if [[ "$WRITE_MANAGED_CONFIG" == "1" ]]; then
    write_config
  else
    preserve_or_default_config
  fi
  if [[ "$SYNC_PROVIDER_HISTORY" == "1" ]]; then
    sync_provider_history "$source_dir"
  fi
  if [[ "$INSTALL_TEMPLATES" == "1" ]]; then
    install_rules_and_templates "$source_dir"
  fi
  setup_shell_rc

  print_completion
}

main "$@"
