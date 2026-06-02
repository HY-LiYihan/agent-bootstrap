# Edit YOUR_TOKEN and YOUR_CLAUDE_BASE_URL, then run this file or paste the command.
$env:AGENT='claudecode'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_CLAUDE_BASE_URL'
$env:AGENT_MODEL='claude-sonnet-4-5'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
