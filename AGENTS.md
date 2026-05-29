# Agent Bootstrap Maintainer Notes

## Repository Context

- GitHub owner/account: `HY-LiYihan`
- Primary branch: `main`
- Fixed install refs: `stable` and `latest` branches
- Public install entrypoints use `https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/...`

## Secret Handling

- Never commit real API tokens, gateway keys, private headers, or user-specific credentials.
- Treat API base URLs as sensitive when they identify private gateways or paid routing services.
- Do not paste real `AGENT_TOKEN`, `CODEX_TOKEN`, `CLAUDE_TOKEN`, `OPENCLAW_TOKEN`, `OPENAI_API_KEY`, or similar values into docs, commits, release notes, logs, or examples.
- Use placeholders such as `YOUR_TOKEN`, `YOUR_BASE_URL`, `YOUR_CODEX_BASE_URL`, or `test-token`.
- Before committing, run a quick scan for leaked secrets, for example:

```bash
rg -n "sk-|sssaicode-|TOKEN=.*|KEY=.*|BASE_URL=.*" .
```

## Release Discipline

- After changing public install scripts, push `main` and move both fixed branches. Do not recreate moving `stable` or `latest` tags because raw GitHub can cache or prefer same-name tags over branches.

```bash
git push origin main
git push -f origin HEAD:refs/heads/stable HEAD:refs/heads/latest
```

- For user-facing changes, also create an immutable version tag and GitHub Release, for example `v5.4.1`.
- After moving `stable`, verify the remote raw script and an end-to-end dry-run, not just the local file:

```bash
curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent | rg "Agent Bootstrap Wizard|Codex ready|stable"
CODEX_TOKEN=test-token CODEX_API_URL=https://example.test/v1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.sh)" -- --dry-run --skip-codex-install --skip-shell-rc --yes
```

## Safety Expectations

- Keep one-line commands explicit: no hidden default token, no hidden default private base URL.
- Prefer interactive prompts when token/base URL are missing.
- Preserve existing local `AGENTS.md` in user projects unless the user explicitly asks to overwrite it.
- When adding examples, ensure they are copy-editable but use placeholders only.
