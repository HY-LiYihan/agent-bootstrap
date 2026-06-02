# Agent Bootstrap default/menu entrypoint for Windows PowerShell.
# Default: $env:AGENT_TOKEN='YOUR_TOKEN'; $env:AGENT_BASE_URL='YOUR_BASE_URL'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex
# Menu:    $env:AGENT_BOOTSTRAP_MENU='1'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex
param([switch]$Menu)

$ErrorActionPreference = 'Stop'
$repo = if ($env:BOOTSTRAP_REPO) { $env:BOOTSTRAP_REPO } else { 'HY-LiYihan/agent-bootstrap' }
$ref = if ($env:BOOTSTRAP_REF) { $env:BOOTSTRAP_REF } else { 'stable' }
$raw = "https://raw.githubusercontent.com/$repo/$ref"

function Ask-Value {
    param([string]$Prompt, [string]$Default = '')
    if ($Default) { $answer = Read-Host "$Prompt [$Default]" } else { $answer = Read-Host $Prompt }
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer
}

function Invoke-AgentInstaller {
    param(
        [string]$Agent,
        [string]$Token,
        [string]$BaseUrl,
        [string]$Model = ''
    )
    $env:AGENT = $Agent
    $env:AGENT_TOKEN = $Token
    $env:AGENT_BASE_URL = $BaseUrl
    if ($Model) { $env:AGENT_MODEL = $Model }

    if ($env:AGENT_BOOTSTRAP_LOCAL_SOURCE -and (Test-Path (Join-Path $env:AGENT_BOOTSTRAP_LOCAL_SOURCE 'install.ps1'))) {
        & (Join-Path $env:AGENT_BOOTSTRAP_LOCAL_SOURCE 'install.ps1')
        return
    }
    irm "$raw/install.ps1" | iex
}

function Assert-TokenAndBaseUrl {
    param([string]$Token, [string]$BaseUrl)
    if (-not $Token -or -not $BaseUrl) {
        throw 'AGENT_TOKEN and AGENT_BASE_URL are both required.'
    }
}

function Show-Banner {
    param([string]$Title, [string]$Subtitle)
    Write-Host ''
    Write-Host '+--------------------------------------------------+' -ForegroundColor Cyan
    Write-Host (("| $Title").PadRight(51) + '|') -ForegroundColor Cyan
    Write-Host (("| $Subtitle").PadRight(51) + '|') -ForegroundColor Cyan
    Write-Host '+--------------------------------------------------+' -ForegroundColor Cyan
    Write-Host ''
}

$useMenu = $Menu -or ($env:AGENT_BOOTSTRAP_MENU -eq '1')

if (-not $useMenu) {
    $token = if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:CODEX_TOKEN) { $env:CODEX_TOKEN } else { '' }
    $baseUrl = if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:CODEX_API_URL) { $env:CODEX_API_URL } else { '' }
    if (-not $token -or -not $baseUrl) {
        Write-Host '[ERROR] Missing AGENT_TOKEN or AGENT_BASE_URL. Example: $env:AGENT_TOKEN=''YOUR_TOKEN''; $env:AGENT_BASE_URL=''YOUR_BASE_URL''; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex' -ForegroundColor Red
        Write-Host '[INFO] For interactive setup: $env:AGENT_BOOTSTRAP_MENU=''1''; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex' -ForegroundColor Cyan
        exit 1
    }
    Show-Banner 'Agent Bootstrap Default' 'Codex ready'
    Write-Host "[INFO] Agent: codex" -ForegroundColor Cyan
    Write-Host "[INFO] Base URL: $baseUrl" -ForegroundColor Cyan
    Invoke-AgentInstaller -Agent 'codex' -Token $token -BaseUrl $baseUrl
    return
}

Show-Banner 'Agent Bootstrap Interactive' 'one menu -> one ready agent'
Write-Host 'Choose an install target:'
Write-Host '  1) Codex'
Write-Host '  2) Claude Code'
Write-Host '  3) OpenClaw'
Write-Host '  4) Hermes Agent'
Write-Host '  5) Codex++ App addon'
Write-Host '  6) All four agents with the same token/base URL'
Write-Host '  q) Quit'

$choice = Ask-Value 'Select' '1'
switch ($choice.ToLowerInvariant()) {
    { $_ -in @('1', 'codex') } { $agent = 'codex'; break }
    { $_ -in @('2', 'claude', 'claudecode', 'claude-code') } { $agent = 'claudecode'; break }
    { $_ -in @('3', 'openclaw', 'claw') } { $agent = 'openclaw'; break }
    { $_ -in @('4', 'hermes', 'hermes-agent') } { $agent = 'hermes'; break }
    { $_ -in @('5', 'codexplusplus', 'codex++', 'cpp') } { $agent = 'codexplusplus'; break }
    { $_ -in @('6', 'all') } { $agent = 'all'; break }
    { $_ -in @('q', 'quit') } { Write-Host '[WARN] Cancelled' -ForegroundColor Yellow; return }
    default { throw "Unknown choice: $choice" }
}

if ($agent -eq 'codex') {
    $token = Ask-Value 'API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:CODEX_TOKEN) { $env:CODEX_TOKEN } else { '' })
    Write-Host '[INFO] Codex API base URL is required; no default is bundled' -ForegroundColor Cyan
    $baseUrl = Ask-Value 'Codex API base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:CODEX_API_URL) { $env:CODEX_API_URL } else { '' })
    Assert-TokenAndBaseUrl -Token $token -BaseUrl $baseUrl
    Invoke-AgentInstaller -Agent 'codex' -Token $token -BaseUrl $baseUrl
} elseif ($agent -eq 'claudecode') {
    $token = Ask-Value 'API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:CLAUDE_TOKEN) { $env:CLAUDE_TOKEN } elseif ($env:CLAUDE_CLIENT_TOKEN) { $env:CLAUDE_CLIENT_TOKEN } else { '' })
    Write-Host '[INFO] Claude API base URL is required; no default is bundled' -ForegroundColor Cyan
    $baseUrl = Ask-Value 'Claude API base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:CLAUDE_API_URL) { $env:CLAUDE_API_URL } else { '' })
    Assert-TokenAndBaseUrl -Token $token -BaseUrl $baseUrl
    Invoke-AgentInstaller -Agent 'claudecode' -Token $token -BaseUrl $baseUrl
} elseif ($agent -eq 'openclaw') {
    $token = Ask-Value 'API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:OPENCLAW_TOKEN) { $env:OPENCLAW_TOKEN } else { '' })
    Write-Host '[INFO] OpenClaw base URL is required; no default is bundled' -ForegroundColor Cyan
    $baseUrl = Ask-Value 'OpenClaw base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:OPENCLAW_BASE_URL) { $env:OPENCLAW_BASE_URL } else { '' })
    $model = Ask-Value 'OpenClaw model' $(if ($env:AGENT_MODEL) { $env:AGENT_MODEL } elseif ($env:OPENCLAW_MODEL) { $env:OPENCLAW_MODEL } else { 'anthropic/claude-opus-4-7' })
    Assert-TokenAndBaseUrl -Token $token -BaseUrl $baseUrl
    Invoke-AgentInstaller -Agent 'openclaw' -Token $token -BaseUrl $baseUrl -Model $model
} elseif ($agent -eq 'hermes') {
    $token = Ask-Value 'API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:HERMES_API_KEY) { $env:HERMES_API_KEY } elseif ($env:HERMES_TOKEN) { $env:HERMES_TOKEN } else { '' })
    Write-Host '[INFO] Hermes base URL is required; no default is bundled' -ForegroundColor Cyan
    $baseUrl = Ask-Value 'Hermes base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:HERMES_BASE_URL) { $env:HERMES_BASE_URL } else { '' })
    $model = Ask-Value 'Hermes model' $(if ($env:AGENT_MODEL) { $env:AGENT_MODEL } elseif ($env:HERMES_MODEL) { $env:HERMES_MODEL } else { 'gpt-5.5' })
    Assert-TokenAndBaseUrl -Token $token -BaseUrl $baseUrl
    Invoke-AgentInstaller -Agent 'hermes' -Token $token -BaseUrl $baseUrl -Model $model
} elseif ($agent -eq 'codexplusplus') {
    Write-Host '[INFO] Codex++ is an optional Codex App enhancer. It does not need an API token or base URL.' -ForegroundColor Cyan
    $ref = if ($env:CODEX_PLUS_PLUS_REF) { $env:CODEX_PLUS_PLUS_REF } else { 'v1.0.7' }
    Write-Host "[INFO] Default upstream: BigPizzaV3/CodexPlusPlus@$ref" -ForegroundColor Cyan
    Invoke-AgentInstaller -Agent 'codexplusplus' -Token '' -BaseUrl ''
} else {
    $sharedToken = Ask-Value 'Shared API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } else { '' })
    Write-Host '[INFO] Non-Codex base URL is required; no default is bundled' -ForegroundColor Cyan
    $sharedBase = Ask-Value 'Shared non-Codex base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } else { '' })
    Write-Host '[INFO] Codex API base URL is required; no default is bundled' -ForegroundColor Cyan
    $codexBase = Ask-Value 'Codex API base URL' $(if ($env:CODEX_API_URL) { $env:CODEX_API_URL } else { '' })
    $model = Ask-Value 'OpenClaw model' $(if ($env:AGENT_MODEL) { $env:AGENT_MODEL } elseif ($env:OPENCLAW_MODEL) { $env:OPENCLAW_MODEL } else { 'anthropic/claude-opus-4-7' })
    $hermesModel = Ask-Value 'Hermes model' $(if ($env:HERMES_MODEL) { $env:HERMES_MODEL } else { 'gpt-5.5' })
    Assert-TokenAndBaseUrl -Token $sharedToken -BaseUrl $sharedBase
    Assert-TokenAndBaseUrl -Token $sharedToken -BaseUrl $codexBase

    Invoke-AgentInstaller -Agent 'codex' -Token $sharedToken -BaseUrl $codexBase
    Invoke-AgentInstaller -Agent 'claudecode' -Token $sharedToken -BaseUrl $sharedBase
    Invoke-AgentInstaller -Agent 'openclaw' -Token $sharedToken -BaseUrl $sharedBase -Model $model
    Invoke-AgentInstaller -Agent 'hermes' -Token $sharedToken -BaseUrl $sharedBase -Model $hermesModel
}

Write-Host '[OK] Agent Bootstrap finished' -ForegroundColor Green
