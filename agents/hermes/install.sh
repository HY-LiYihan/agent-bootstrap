#!/usr/bin/env bash
# Hermes Agent bootstrap for macOS/Linux.

set -euo pipefail
IFS=$'\n\t'

HERMES_TOKEN_VALUE="${HERMES_API_KEY:-${HERMES_TOKEN:-${OPENAI_API_KEY:-${AGENT_TOKEN:-}}}}"
HERMES_BASE_URL_VALUE="${HERMES_BASE_URL:-${OPENAI_BASE_URL:-${AGENT_BASE_URL:-}}}"
HERMES_MODEL_VALUE="${HERMES_MODEL:-${AGENT_MODEL:-gpt-5.5}}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
CONFIG_FILE="$HERMES_HOME/config.yaml"
ENV_FILE="$HERMES_HOME/.env"
INSTALL_REF="${HERMES_INSTALL_REF:-main}"
DRY_RUN=0
FORCE=0
SKIP_INSTALL=0
SKIP_BROWSER=1
NO_SKILLS=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
step() { printf "\n%b[%s]%b %b%s%b\n" "$MAGENTA" "$1" "$NC" "$BOLD" "$2" "$NC"; }
ok() { printf "%b[OK]%b %s\n" "$GREEN" "$NC" "$1"; }
info() { printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$1"; }
warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
fail() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2; exit 1; }

usage() {
  cat <<USAGE
Hermes Agent Bootstrap

Usage:
  HERMES_API_KEY=... HERMES_BASE_URL=... HERMES_MODEL=gpt-5.5 agents/hermes/install.sh

Options:
  --dry-run       Print actions without writing files
  --force         Reinstall even when hermes already exists
  --skip-install  Only write Hermes config
  --with-browser  Let upstream install Playwright/browser dependencies
  --no-skills     Ask upstream installer to skip bundled skills
  --ref REF       Upstream branch/ref for NousResearch/hermes-agent (default: main)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --skip-install|--skip-hermes-install) SKIP_INSTALL=1; shift ;;
    --with-browser) SKIP_BROWSER=0; shift ;;
    --no-skills) NO_SKILLS=1; shift ;;
    --ref) INSTALL_REF="${2:?missing ref}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN:"; printf " %q" "$@"; printf "\n"
  else
    "$@"
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }
mask_secret() { local value="$1"; if [[ ${#value} -le 8 ]]; then printf "<hidden>"; else printf "%s...%s" "${value:0:4}" "${value: -4}"; fi; }
mask_url() { [[ -n "$1" ]] && printf "<configured>" || printf "<missing>"; }

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  run cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
}

validate_required_inputs() {
  [[ -n "$HERMES_TOKEN_VALUE" ]] || fail "Missing HERMES_API_KEY, HERMES_TOKEN, OPENAI_API_KEY, or AGENT_TOKEN"
  [[ -n "$HERMES_BASE_URL_VALUE" ]] || fail "Missing HERMES_BASE_URL, OPENAI_BASE_URL, or AGENT_BASE_URL"
  [[ -n "$HERMES_MODEL_VALUE" ]] || fail "Missing HERMES_MODEL or AGENT_MODEL"
}

install_hermes() {
  if [[ "$SKIP_INSTALL" == "1" ]]; then info "Skipping Hermes install"; return 0; fi
  if command_exists hermes && [[ "$FORCE" != "1" ]]; then ok "Hermes already installed: $(command -v hermes)"; return 0; fi

  local upstream_args=(--skip-setup --non-interactive --branch "$INSTALL_REF")
  [[ "$SKIP_BROWSER" == "1" ]] && upstream_args+=(--skip-browser)
  [[ "$NO_SKILLS" == "1" ]] && upstream_args+=(--no-skills)

  info "Trying official Hermes installer"
  if [[ "$DRY_RUN" == "1" ]]; then
    run bash -c "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- ${upstream_args[*]}"
    return 0
  fi

  if curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- "${upstream_args[@]}"; then
    ok "Hermes installed with official installer"
    return 0
  fi

  warn "Official installer failed; trying pip fallback"
  if command_exists pipx; then
    run pipx install --force "git+https://github.com/NousResearch/hermes-agent.git@${INSTALL_REF}"
  elif command_exists python3; then
    run python3 -m pip install --user --upgrade "git+https://github.com/NousResearch/hermes-agent.git@${INSTALL_REF}"
  elif command_exists python; then
    run python -m pip install --user --upgrade "git+https://github.com/NousResearch/hermes-agent.git@${INSTALL_REF}"
  else
    fail "Python or pipx is required for Hermes fallback install"
  fi
}

write_hermes_config() {
  validate_required_inputs
  run mkdir -p "$HERMES_HOME"
  backup_file "$CONFIG_FILE"
  backup_file "$ENV_FILE"

  if [[ "$DRY_RUN" == "1" ]]; then
    info "Would write Hermes config to $CONFIG_FILE"
    info "Would write Hermes env to $ENV_FILE with token $(mask_secret "$HERMES_TOKEN_VALUE")"
    return 0
  fi

  cat > "$ENV_FILE" <<ENV
OPENAI_API_KEY=$HERMES_TOKEN_VALUE
OPENAI_BASE_URL=$HERMES_BASE_URL_VALUE
HERMES_API_KEY=$HERMES_TOKEN_VALUE
HERMES_BASE_URL=$HERMES_BASE_URL_VALUE
ENV
  chmod 600 "$ENV_FILE" 2>/dev/null || true

  cat > "$CONFIG_FILE" <<YAML
model:
  provider: "custom"
  default: "$HERMES_MODEL_VALUE"
  base_url: "$HERMES_BASE_URL_VALUE"

terminal:
  backend: "local"
YAML
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true

  ok "Hermes config ready: $CONFIG_FILE"
  ok "Hermes env ready: $ENV_FILE"
}

main() {
  printf "\n%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  printf "%b|%b %bHermes Agent Bootstrap%b                         %b|%b\n" "$CYAN" "$NC" "$BOLD" "$NC" "$CYAN" "$NC"
  printf "%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  step "1/5" "Inspect Hermes settings"
  info "Hermes home: $HERMES_HOME"
  info "Base URL: $(mask_url "$HERMES_BASE_URL_VALUE")"
  info "Model: $HERMES_MODEL_VALUE"
  [[ -n "$HERMES_TOKEN_VALUE" ]] && info "Token: $(mask_secret "$HERMES_TOKEN_VALUE")"
  validate_required_inputs
  step "2/5" "Install or verify Hermes CLI"
  install_hermes
  step "3/5" "Write Hermes API and model config"
  write_hermes_config
  step "4/5" "Check Hermes command"
  if command_exists hermes; then ok "Hermes command available: $(command -v hermes)"; else warn "Hermes command not on PATH yet; restart shell or check ~/.local/bin"; fi
  step "5/5" "Finish"
  ok "Hermes Agent bootstrap completed"
  info "Try: hermes"
}

main
