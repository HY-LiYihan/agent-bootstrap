# Edit YOUR_TOKEN and YOUR_CLAUDE_BASE_URL, then run this file or paste the command.
AGENT=claudecode \
AGENT_TOKEN="YOUR_TOKEN" \
AGENT_BASE_URL="YOUR_CLAUDE_BASE_URL" \
AGENT_MODEL="claude-sonnet-4-5" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
