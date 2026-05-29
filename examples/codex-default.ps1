# Edit YOUR_TOKEN and YOUR_CODEX_BASE_URL, then run this file or paste the command.
$env:CODEX_TOKEN='YOUR_TOKEN'
$env:CODEX_API_URL='YOUR_CODEX_BASE_URL'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.ps1 | iex
