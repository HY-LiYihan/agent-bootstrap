#!/usr/bin/env bash
# Claude Code bootstrap for macOS/Linux.

set -euo pipefail
IFS=$'\n\t'

CLAUDE_TOKEN_VALUE="${CLAUDE_TOKEN:-${CLAUDE_CLIENT_TOKEN:-}}"
CLAUDE_BASE_URL="${CLAUDE_API_URL:-}"
CLAUDE_MODEL_VALUE="${CLAUDE_MODEL:-${ANTHROPIC_MODEL:-${AGENT_MODEL:-}}}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_HOME/settings.json"
CLAUDE_JSON_FILE="${CLAUDE_JSON_FILE:-$HOME/.claude.json}"
DRY_RUN=0
FORCE=0
SKIP_INSTALL=0
NO_BUN=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
step() { printf "\n%b[%s]%b %b%s%b\n" "$MAGENTA" "$1" "$NC" "$BOLD" "$2" "$NC"; }
ok() { printf "%b[OK]%b %s\n" "$GREEN" "$NC" "$1"; }
info() { printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$1"; }
warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
fail() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --skip-claude-install|--skip-install) SKIP_INSTALL=1; shift ;;
    --no-bun) NO_BUN=1; shift ;;
    -h|--help)
      echo "Usage: CLAUDE_TOKEN=... CLAUDE_API_URL=... CLAUDE_MODEL=... agents/claudecode/install.sh"
      exit 0
      ;;
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

mask_secret() {
  local value="$1"
  if [[ ${#value} -le 8 ]]; then printf "<hidden>"; else printf "%s...%s" "${value:0:4}" "${value: -4}"; fi
}
mask_url() {
  [[ -n "$1" ]] && printf "<configured>" || printf "<missing>"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

shell_rc() {
  if [[ "${SHELL:-}" == *zsh* ]]; then printf "%s/.zshrc" "$HOME"; elif [[ "${SHELL:-}" == *bash* ]]; then [[ "$(uname -s)" == "Darwin" ]] && printf "%s/.bash_profile" "$HOME" || printf "%s/.bashrc" "$HOME"; else printf "%s/.profile" "$HOME"; fi
}

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  run cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
}

validate_required_inputs() {
  [[ -n "$CLAUDE_TOKEN_VALUE" ]] || fail "Missing CLAUDE_TOKEN or CLAUDE_CLIENT_TOKEN"
  [[ -n "$CLAUDE_BASE_URL" ]] || fail "Missing CLAUDE_API_URL"
}

ensure_bun() {
  [[ "$NO_BUN" == "0" ]] || return 1
  if command_exists bun; then ok "Bun found: $(bun --version)"; return 0; fi
  info "Installing Bun runtime"
  if [[ "$DRY_RUN" == "1" ]]; then
    run bash -c 'curl -fsSL https://bun.sh/install | bash'
  else
    curl -fsSL https://bun.sh/install | bash || return 1
  fi
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  command_exists bun
}

install_claude() {
  if [[ "$SKIP_INSTALL" == "1" ]]; then info "Skipping Claude Code install"; return 0; fi
  if command_exists claude && [[ "$FORCE" != "1" ]]; then ok "Claude already installed: $(command -v claude)"; return 0; fi

  info "Trying official Claude Code installer"
  if [[ "$DRY_RUN" == "1" ]]; then
    run bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
    return 0
  fi

  if curl -fsSL https://claude.ai/install.sh | bash; then
    ok "Claude Code installed with official installer"
    return 0
  fi

  warn "Official installer failed; trying Bun package"
  ensure_bun || fail "Bun is required for fallback install"
  bun install -g @anthropic-ai/claude-code

  local postinstall="$HOME/.bun/install/global/node_modules/@anthropic-ai/claude-code/install.cjs"
  if [[ -f "$postinstall" ]] && command_exists node; then
    node "$postinstall" || warn "Claude native binary postinstall failed; try: node $postinstall"
  fi
}

write_claude_settings() {
  validate_required_inputs
  run mkdir -p "$CLAUDE_HOME"
  backup_file "$SETTINGS_FILE"
  backup_file "$CLAUDE_JSON_FILE"

  if [[ "$DRY_RUN" == "1" ]]; then
    info "Would write Claude settings to $SETTINGS_FILE with token $(mask_secret "$CLAUDE_TOKEN_VALUE")"
    [[ -n "$CLAUDE_MODEL_VALUE" ]] && info "Would set Claude default model: $CLAUDE_MODEL_VALUE"
    return 0
  fi

  if command_exists python3; then
    SETTINGS_FILE="$SETTINGS_FILE" CLAUDE_JSON_FILE="$CLAUDE_JSON_FILE" CLAUDE_TOKEN_VALUE="$CLAUDE_TOKEN_VALUE" CLAUDE_BASE_URL="$CLAUDE_BASE_URL" CLAUDE_MODEL_VALUE="$CLAUDE_MODEL_VALUE" python3 - <<'PY'
import json, os
settings_file = os.environ['SETTINGS_FILE']
claude_json_file = os.environ['CLAUDE_JSON_FILE']
token = os.environ['CLAUDE_TOKEN_VALUE']
base_url = os.environ['CLAUDE_BASE_URL']
model = os.environ.get('CLAUDE_MODEL_VALUE', '')
try:
    with open(settings_file, 'r', encoding='utf-8') as f:
        settings = json.load(f)
except Exception:
    settings = {}
settings.setdefault('env', {})
settings['env'].update({
    'ANTHROPIC_AUTH_TOKEN': token,
    'ANTHROPIC_BASE_URL': base_url,
    'API_TIMEOUT_MS': 600000,
    'CLAUDE_CODE_DISABLE_TERMINAL_TITLE': '1',
    'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC': '1',
})
if model:
    settings['model'] = model
    settings['env']['ANTHROPIC_MODEL'] = model
settings.setdefault('permissions', {'allow': [], 'deny': []})
os.makedirs(os.path.dirname(settings_file), exist_ok=True)
with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2)
try:
    with open(claude_json_file, 'r', encoding='utf-8') as f:
        claude_json = json.load(f)
except Exception:
    claude_json = {}
claude_json['hasCompletedOnboarding'] = True
with open(claude_json_file, 'w', encoding='utf-8') as f:
    json.dump(claude_json, f, indent=2)
PY
  else
    if [[ -n "$CLAUDE_MODEL_VALUE" ]]; then
      cat > "$SETTINGS_FILE" <<JSON
{
  "model": "$CLAUDE_MODEL_VALUE",
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$CLAUDE_TOKEN_VALUE",
    "ANTHROPIC_BASE_URL": "$CLAUDE_BASE_URL",
    "ANTHROPIC_MODEL": "$CLAUDE_MODEL_VALUE",
    "API_TIMEOUT_MS": 600000,
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "permissions": { "allow": [], "deny": [] }
}
JSON
    else
      cat > "$SETTINGS_FILE" <<JSON
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$CLAUDE_TOKEN_VALUE",
    "ANTHROPIC_BASE_URL": "$CLAUDE_BASE_URL",
    "API_TIMEOUT_MS": 600000,
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "permissions": { "allow": [], "deny": [] }
}
JSON
    fi
    printf '{"hasCompletedOnboarding":true}\n' > "$CLAUDE_JSON_FILE"
  fi
  ok "Claude settings configured: $SETTINGS_FILE"
}

ensure_path() {
  local rc path_line
  rc="$(shell_rc)"
  path_line='export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"'
  if [[ "$DRY_RUN" == "1" ]]; then info "Would ensure Claude PATH in $rc"; return 0; fi
  touch "$rc"
  if ! grep -Fq '.local/bin:$HOME/.bun/bin' "$rc"; then
    printf '\n# Agent Bootstrap Claude Code PATH\n%s\n' "$path_line" >> "$rc"
  fi
  ok "Shell PATH configured: $rc"
}

main() {
  printf "\n%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  printf "%b|%b %bClaude Code Bootstrap%b                           %b|%b\n" "$CYAN" "$NC" "$BOLD" "$NC" "$CYAN" "$NC"
  printf "%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  step "1/7" "Inspect Claude Code settings"
  info "OS: $(uname -s)/$(uname -m)"
  info "API URL: $(mask_url "$CLAUDE_BASE_URL")"
  [[ -n "$CLAUDE_MODEL_VALUE" ]] && info "Model: $CLAUDE_MODEL_VALUE"
  [[ -n "$CLAUDE_TOKEN_VALUE" ]] && info "Token: $(mask_secret "$CLAUDE_TOKEN_VALUE")"
  validate_required_inputs
  step "2/7" "Verify config directories"
  info "Claude home: $CLAUDE_HOME"
  step "3/7" "Install or verify Claude Code CLI"
  install_claude
  step "4/7" "Write Claude credentials and API URL"
  write_claude_settings
  step "5/7" "Write onboarding marker"
  ok "Onboarding marker handled via $CLAUDE_JSON_FILE"
  step "6/7" "Ensure Claude command is on PATH"
  ensure_path
  step "7/7" "Finish"
  ok "Claude Code bootstrap completed"
  info "Try: claude"
}

main
