# Edit YOUR_TOKEN, YOUR_HERMES_BASE_URL, and optionally AGENT_MODEL, then run this file or paste the command.
$env:AGENT='hermes'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_HERMES_BASE_URL'
$env:AGENT_MODEL='gpt-5.5'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
