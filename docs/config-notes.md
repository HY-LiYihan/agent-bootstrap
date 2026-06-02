# Codex Config Notes

The current bootstrap default intentionally uses a custom provider because this is the most direct shape for API gateway setups. The default `CODEX_SECURITY_PROFILE=max` writes:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
model_verbosity = "medium"
model_reasoning_summary = "auto"
model_provider = "custom"
web_search = "live"
project_doc_max_bytes = 65536
approval_policy = "never"
sandbox_mode = "danger-full-access"

[model_providers."custom"]
name = "custom"
base_url = "https://your-gateway.example.com/v1"
wire_api = "responses"
env_key = "CODEX_API_KEY"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
```

The stable installer intentionally fixes the provider id to `custom`. If `CODEX_PROVIDER_ID` is set to another value, the installer warns and ignores it so old session metadata, SQLite state, and config output stay aligned.

The API key is stored in `~/.codex/private.env` instead of being written directly into `.zshrc` or `.bashrc`.

## Baseline usability defaults

The bootstrap also writes:

- `preferred_auth_method = "apikey"` so gateway tokens are used directly.
- `disable_response_storage = true` to reduce remote response retention.
- `web_search = "live"` so the Responses web search tool favors fresh results.
- `model_verbosity = "medium"` and `model_reasoning_summary = "auto"` for more useful explanations without forcing maximum verbosity.
- `project_doc_max_bytes = 65536` so larger `AGENTS.md` files are included more completely.
- Provider retry and stream timeout values are written explicitly for gateway predictability.
- `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` for fully autonomous local execution.
- Provider history sync updates original Codex session JSONL/JSON files and SQLite `model_provider` columns to the active provider name, with backups first and a post-sync verification pass.

Because this is a high-permission setup, the installed `AGENTS.md` and `default.rules` emphasize path checks, secret protection, backups, and narrow verification after edits. Plugin and project-trust overrides are intentionally outside the minimal stable config so provider setup stays predictable.

## Safe profile

Set `CODEX_SECURITY_PROFILE=safe` to keep Codex's approval policy, sandbox mode, plugin enablement, and project trust at official defaults while still writing the custom gateway provider:

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
base_url = "https://your-gateway.example.com/v1"
wire_api = "responses"
env_key = "CODEX_API_KEY"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
```
