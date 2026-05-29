# CCSwitch Replacement Notes

Agent Bootstrap replaces the core day-to-day provider switching workflow with a repo-native, scriptable CLI:

- Prepare one agent with one command using the same `AGENT`, `AGENT_TOKEN`, and `AGENT_BASE_URL` contract everywhere.
- Store named gateway profiles in `~/.agent-bootstrap/profiles.json`.
- Apply one profile to Codex, Claude Code, and OpenClaw with `switch.js use <name>`.
- Add Codex++ as an optional Codex App enhancer with a separate one-line install, without mixing it into provider switching.
- Keep fixed remote entrypoints through `stable` and `latest` branches.
- Avoid printing full tokens; store profile state with file mode `600` where supported.
- For Claude Code, write both `settings.json` and shell env helpers that unset `CLAUDE_CODE_OAUTH_TOKEN`, which can otherwise override API-token settings.

## Ready One Agent

Codex:

```bash
AGENT=codex AGENT_TOKEN=YOUR_TOKEN AGENT_BASE_URL=YOUR_CODEX_BASE_URL bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

Claude Code:

```bash
AGENT=claudecode AGENT_TOKEN=YOUR_TOKEN AGENT_BASE_URL=YOUR_CLAUDE_BASE_URL bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

OpenClaw:

```bash
AGENT=openclaw AGENT_TOKEN=YOUR_TOKEN AGENT_BASE_URL=YOUR_OPENCLAW_BASE_URL AGENT_MODEL=anthropic/claude-opus-4-7 bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

Codex++ addon:

```bash
AGENT=codexplusplus bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

Codex++ is intentionally not part of `switch.js use`: it enhances the Codex App launcher and session UI, while `switch.js` owns provider/profile switching.

## Common Workflow

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.sh)" -- add sss \
  --token YOUR_TOKEN \
  --base-url https://example.test/api \
  --codex-url https://example.test/v1 \
  --openclaw-model anthropic/claude-opus-4-7

bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.sh)" -- use sss
```

## Claude Code Shell Hook

After applying a profile, run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.sh)" -- shell-hook
```

Add the printed line to your shell rc if you want new shells to automatically use the active Claude Code API-token environment.
