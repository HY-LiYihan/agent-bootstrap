# Edit YOUR_TOKEN, YOUR_HERMES_BASE_URL, and optionally HERMES_MODEL, then run this file or paste the command.
AGENT=hermes \
AGENT_TOKEN="YOUR_TOKEN" \
AGENT_BASE_URL="YOUR_HERMES_BASE_URL" \
AGENT_MODEL="gpt-5.5" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
