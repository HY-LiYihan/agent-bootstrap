# Agent Bootstrap

One-click bootstrapper focused on making Codex installation repeatable on macOS, Ubuntu/Linux, and Windows. Other agents remain in the repo, but the stable path is now optimized for Codex first.

## Command Generator

Use the web command generator if you want a copy-paste install command without editing shell snippets by hand:

```text
https://hy-liyihan.github.io/agent-bootstrap/
```

Paste your API key, base URL, and optional default model in the page, choose Codex, Claude Code, OpenClaw, or Hermes Agent, then copy the generated macOS, Linux, or Windows command. The page is static HTML; it does not send, store, or put your API key into the URL. It also supports English/Chinese copy with best-effort IP-region language detection and a manual language switch.

## Stable Codex Install

macOS:

```bash
CODEX_TOKEN="YOUR_TOKEN" CODEX_API_URL="YOUR_BASE_URL" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.sh)"
```

Ubuntu/Linux:

```bash
CODEX_TOKEN="YOUR_TOKEN" CODEX_API_URL="YOUR_BASE_URL" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.sh)"
```

Windows PowerShell:

```powershell
$env:CODEX_TOKEN='YOUR_TOKEN'; $env:CODEX_API_URL='YOUR_BASE_URL'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.ps1 | iex
```

The stable command has no bundled token and no bundled private base URL. Both values must be provided explicitly.

## Safety And Restore

Before writing Codex files, the Codex installer backs up the whole Codex home by default:

```text
~/.codex.backup.YYYYMMDDHHMMSS
```

The backup contains a full copy of:

- `~/.codex/`

By default, the installer does not modify project `AGENTS.md`, Codex rules, provider history, or an existing `~/.codex/config.toml`.

Restore on macOS/Ubuntu/Linux:

```bash
CODEX_HOME="$HOME/.codex" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.sh)" -- --restore "$HOME/.codex.backup.YYYYMMDDHHMMSS"
```

Restore on Windows PowerShell:

```powershell
$env:CODEX_HOME="$HOME\.codex"; $env:CODEX_PROJECT_DIR=(Get-Location).Path; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.ps1 -OutFile "$env:TEMP\install-codex.ps1"; & "$env:TEMP\install-codex.ps1" -Restore "$HOME\.codex\backups_state\install\YYYYMMDDHHMMSS"
```

Disable the pre-install restore snapshot only when you already have an external backup:

```bash
... install-codex.sh --no-install-backup
```

```powershell
.\install-codex.ps1 # default creates a backup; use agents\codex\install.ps1 -NoInstallBackup only for local advanced use
```

After confirming Codex works, delete macOS/Linux Codex install backups with:

```bash
find "$HOME" -maxdepth 1 -type d -name '.codex.backup.*' -prune -exec rm -rf {} +
```

## Download Reliability

The public entrypoints download this repository through GitHub codeload branch archives, then validate the archive before extraction. `stable` and `latest` are maintained as branches, not moving tags, to avoid raw GitHub tag-cache ambiguity.

## Supported Agents

- `codex`: installs or verifies OpenAI Codex CLI, writes API env, and preserves existing Codex config by default.
- `claudecode`: installs/configures Claude Code with `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_BASE_URL`.
- `openclaw`: writes OpenClaw model and auth JSON config.
- `hermes`: installs/configures [NousResearch Hermes Agent](https://github.com/NousResearch/hermes-agent) with a custom OpenAI-compatible gateway.

## Supported Addons

- `codexplusplus`: installs [BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus), an external Codex App enhancer that unlocks plugin entry points, session deletion/export, timeline, and provider metadata sync. It does not write API keys or provider config.

Aliases:

- `codex`, `openai-codex`
- `claudecode`, `claude`, `claude-code`
- `openclaw`, `claw`
- `hermes`, `hermes-agent`
- `codexplusplus`, `codex-plus-plus`, `codex++`, `cpp`

## Quick Start

Recommended stable Codex-only install:

```bash
CODEX_TOKEN="YOUR_TOKEN" CODEX_API_URL="YOUR_BASE_URL" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.sh)"
```

This path intentionally does the stable minimum: detect the environment, back up the whole `~/.codex` folder, install or verify Codex CLI, store API environment variables in `~/.codex/private.env`, and add a shell startup source line. If `~/.codex/config.toml` already exists, it is left unchanged. If it does not exist, the installer leaves it absent so Codex uses official defaults. On a fresh machine, the installer first tries Bun, falls back to npm, and can install Node.js through NVM when npm is missing.

There are also three broader entry styles:

1. macOS/Linux wizard: one command, then enter `base_url` and `key`, choose high-autonomy or safe Codex config, and optionally install Codex++.
2. Direct install: pass env values up front for non-interactive setup.
3. Interactive menu: choose Codex, Claude Code, OpenClaw, Hermes Agent, Codex++, or all provider-configured agents.

macOS/Linux wizard:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && . ./agent
```

If `wget` is unavailable:

```bash
curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -o agent && . ./agent
```

If you already have env vars set but still want the wizard:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && . ./agent --wizard
```

The wizard never uses a hidden key or base URL. It asks for both values explicitly, then offers:

- `Maximum autonomy`: writes `approval_policy = "never"` and `sandbox_mode = "danger-full-access"`.
- `Official safe defaults`: leaves approval policy, sandbox mode, and project trust at Codex defaults.
- `Codex++ addon`: optional install, optional provider sync, optional immediate launch.

Codex runtime fallback controls:

- `--no-bun`: skip automatic Bun installation and use npm directly.
- `--no-node`: do not install Node.js through NVM if npm is missing.
- `CODEX_NODE_VERSION`: override the Node.js version used by the NVM fallback.

Non-interactive Codex install on macOS/Linux:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_BASE_URL" . ./agent
```

Non-interactive Codex install on Windows PowerShell:

```powershell
$env:AGENT_TOKEN='YOUR_TOKEN'; $env:AGENT_BASE_URL='YOUR_BASE_URL'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex
```

Interactive menu, similar in spirit to `wget http://fishros.com/install -O fishros && . fishros`:

macOS/Linux:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && . ./agent --menu
```

If `wget` is unavailable:

```bash
curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -o agent && . ./agent --menu
```

Windows PowerShell:

```powershell
$env:AGENT_BOOTSTRAP_MENU='1'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex
```

The default non-interactive mode writes the high-autonomy Codex config, but it does not provide a built-in key or base URL. The wizard and menu require you to enter those values explicitly.

Online editable examples:

- [examples/codex-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codex-default.sh)
- [examples/claudecode-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/claudecode-default.sh)
- [examples/openclaw-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/openclaw-default.sh)
- [examples/hermes-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/hermes-default.sh)
- [examples/codexplusplus-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codexplusplus-default.sh)
- [examples/codex-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codex-default.ps1)
- [examples/claudecode-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/claudecode-default.ps1)
- [examples/openclaw-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/openclaw-default.ps1)
- [examples/hermes-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/hermes-default.ps1)
- [examples/codexplusplus-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codexplusplus-default.ps1)

Direct one-line install remains supported:

The main contract is deliberately simple:

- `AGENT`: `codex`, `claudecode`, `openclaw`, `hermes`, or `codexplusplus`
- `AGENT_TOKEN`: the API token for that agent/gateway
- `AGENT_BASE_URL`: the API gateway/base URL for that agent
- `AGENT_MODEL`: optional default model override for Codex, Claude Code, OpenClaw, and Hermes
- `CODEX_SECURITY_PROFILE`: `max` or `safe`, default `max`
- `CODEX_PLUS_PLUS_REF`: optional upstream Codex++ ref/tag, default `v1.0.7`

macOS/Linux:

```bash
AGENT=codex AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_CODEX_BASE_URL" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

```bash
AGENT=claudecode AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_CLAUDE_BASE_URL" AGENT_MODEL="claude-sonnet-4-5" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

```bash
AGENT=openclaw AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_OPENCLAW_BASE_URL" AGENT_MODEL="anthropic/claude-opus-4-7" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

```bash
AGENT=hermes AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_HERMES_BASE_URL" AGENT_MODEL="gpt-5.5" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

```bash
AGENT=codexplusplus bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

Windows PowerShell:

```powershell
$env:AGENT='codex'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_CODEX_BASE_URL'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

```powershell
$env:AGENT='claudecode'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_CLAUDE_BASE_URL'
$env:AGENT_MODEL='claude-sonnet-4-5'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

```powershell
$env:AGENT='openclaw'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_OPENCLAW_BASE_URL'
$env:AGENT_MODEL='anthropic/claude-opus-4-7'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

```powershell
$env:AGENT='hermes'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_HERMES_BASE_URL'
$env:AGENT_MODEL='gpt-5.5'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

```powershell
$env:AGENT='codexplusplus'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

## What Gets Written

Codex, maximum-autonomy profile:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
model_verbosity = "medium"
model_reasoning_summary = "auto"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "custom"
web_search = "live"
project_doc_max_bytes = 65536
approval_policy = "never"
sandbox_mode = "danger-full-access"

[model_providers."custom"]
name = "custom"
base_url = "YOUR_CODEX_BASE_URL"
wire_api = "responses"
env_key = "CODEX_API_KEY"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
```

Codex provider history sync:

- Reads the active `model_provider` from `~/.codex/config.toml`.
- Updates `model_provider` fields in Codex session JSONL and JSON files under `~/.codex/sessions` and `~/.codex/archived_sessions`. These files are the original chat records Codex can reopen, so this is not SQLite-only.
- Preserves malformed JSONL lines and provider-free chat records unchanged.
- Updates SQLite tables with a `model_provider` column under the Codex home when SQLite is available and unlocked. SQLite is treated as an app/cache index and is synced in addition to the original JSON/JSONL records.
- Verifies after sync that no remaining JSON/JSONL `model_provider` fields or SQLite `model_provider` rows point at another provider. You can run a read-only check with `node shared/codex-provider-sync.js --codex-home "$HOME/.codex" --provider custom --verify-only --json`.
- Creates backups under `~/.codex/backups_state/provider-sync/YYYYMMDDHHMMSS`.
- Skips SQLite with a warning if the database is locked, so install still completes.

Codex, safe profile:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
model_verbosity = "medium"
model_reasoning_summary = "auto"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "custom"
web_search = "live"
project_doc_max_bytes = 65536

[model_providers."custom"]
name = "custom"
base_url = "YOUR_CODEX_BASE_URL"
wire_api = "responses"
env_key = "CODEX_API_KEY"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
```

Claude Code:

- `~/.claude/settings.json` with `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, optional `ANTHROPIC_MODEL`/`model`, timeout, and traffic-reduction env values.
- `~/.claude.json` with onboarding marked complete.

OpenClaw:

- `~/.openclaw/openclaw.json`
- `~/.openclaw/agents/main/agent/auth-profiles.json`

Hermes Agent:

- `~/.hermes/config.yaml` with `model.provider = custom`, `model.default`, and `model.base_url`.
- `~/.hermes/.env` with `OPENAI_API_KEY`, `OPENAI_BASE_URL`, `HERMES_API_KEY`, and `HERMES_BASE_URL`.

Codex++:

- Installs the upstream Python package from `BigPizzaV3/CodexPlusPlus`, pinned by default to `v1.0.7`.
- Runs `python -m codex_session_delete setup`.
- Writes `~/.codex-session-delete/settings.json` with `providerSyncEnabled` when provider sync is selected.
- On macOS, upstream setup creates `/Applications/Codex++.app`.
- On Windows, upstream setup creates the `Codex++` shortcut/launcher integration.
- It may later write Codex++ runtime data under `~/.codex-session-delete` and provider-sync backups under `~/.codex/backups_state/provider-sync` when used.
- It does not change Codex provider credentials; use `AGENT=codex` first for `~/.codex/config.toml`.

## Local Dry Runs

macOS/Linux:

```bash
AGENT=codex AGENT_TOKEN=test-token AGENT_BASE_URL=https://example.test/v1 AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-codex-install --skip-shell-rc --yes
AGENT=claudecode AGENT_TOKEN=test-token AGENT_BASE_URL=https://example.test/api AGENT_MODEL=claude-sonnet-4-5 AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-claude-install
AGENT=openclaw AGENT_TOKEN=test-token AGENT_BASE_URL=https://example.test/api AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run
AGENT=hermes AGENT_TOKEN=test-token AGENT_BASE_URL=https://example.test/v1 AGENT_MODEL=gpt-5.5 AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-install
AGENT=codexplusplus AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-setup --provider-sync
```

Windows PowerShell:

```powershell
$env:CODEX_TOKEN='test-token'; .\agents\codex\install.ps1 -LocalSource . -DryRun -SkipCodexInstall -SkipProfileUpdate
$env:CLAUDE_CLIENT_TOKEN='test-token'; .\agents\claudecode\install.ps1 -DryRun -SkipInstall
$env:OPENCLAW_TOKEN='test-token'; .\agents\openclaw\install.ps1 -DryRun
$env:HERMES_API_KEY='test-token'; .\agents\hermes\install.ps1 -DryRun -SkipInstall
.\agents\codexplusplus\install.ps1 -DryRun -SkipSetup -ProviderSync 1
```

## Agent Switch

`switch.js` is the provider/profile switcher layer. It is the part meant to replace the day-to-day value of tools like `ccswitch`: save one gateway profile once, then apply it across Codex, Claude Code, and OpenClaw.

Add a profile:

```bash
node switch.js add sss \
  --token YOUR_TOKEN \
  --base-url https://example.test/api \
  --codex-url https://example.test/v1 \
  --openclaw-model anthropic/claude-opus-4-7
```

Apply it everywhere:

```bash
node switch.js use sss
```

Apply it only to Claude Code:

```bash
node switch.js use sss --agents claudecode
```

Fixed curl entrypoints:

macOS/Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.sh)" -- add sss --token YOUR_TOKEN --base-url https://example.test/api
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.sh)" -- use sss
```

Windows PowerShell:

```powershell
$tmp = Join-Path $env:TEMP 'agent-switch.ps1'
Invoke-WebRequest -Uri https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.ps1 -OutFile $tmp
& $tmp add sss --token YOUR_TOKEN --base-url https://example.test/api
& $tmp use sss
```

Check state:

```bash
node switch.js list
node switch.js current
node switch.js doctor
```

Claude Code note:

- The switcher writes `~/.agent-bootstrap/claude-code-env.sh` and `~/.agent-bootstrap/claude-code-env.ps1`.
- Those files unset `CLAUDE_CODE_OAUTH_TOKEN`, because that variable can override API-token based Claude Code settings.
- Run `node switch.js shell-hook` to print the shell/profile line to source the active Claude environment.

## Release Flow

Use semantic version tags for immutable releases, and move the `stable` / `latest` branches to the recommended release so install commands do not need to change. Do not recreate moving `stable` or `latest` tags; raw GitHub can cache or prefer same-name tags.

- `stable`: recommended default install target branch.
- `latest`: branch alias for the newest published install target.
- `vX.Y`: immutable version tags for pinning and rollback.

```bash
git push origin main
git tag vX.Y.Z
git push origin vX.Y.Z
git push -f origin HEAD:refs/heads/stable HEAD:refs/heads/latest
```

## Security Notes

- Do not commit real tokens.
- Prefer passing tokens through environment variables at install time.
- Rotate any token that has been pasted into chats, logs, shell history, or public files.
