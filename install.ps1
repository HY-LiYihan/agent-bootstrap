# Agent Bootstrap dispatcher for Windows PowerShell.
param(
    [string]$Agent = $(if ($env:AGENT) { $env:AGENT } else { "" }),
    [string]$BootstrapRepo = $(if ($env:BOOTSTRAP_REPO) { $env:BOOTSTRAP_REPO } else { "HY-LiYihan/agent-bootstrap" }),
    [string]$BootstrapRef = $(if ($env:BOOTSTRAP_REF) { $env:BOOTSTRAP_REF } else { "stable" }),
    [string]$LocalSource = $(if ($env:AGENT_BOOTSTRAP_LOCAL_SOURCE) { $env:AGENT_BOOTSTRAP_LOCAL_SOURCE } else { "" }),
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Write-Info { param([string]$Message) Write-Host "[INFO] " -NoNewline -ForegroundColor Blue; Write-Host $Message }
function Write-Ok { param([string]$Message) Write-Host "[OK] " -NoNewline -ForegroundColor Green; Write-Host $Message }
function Fail { param([string]$Message) Write-Host "[ERROR] " -NoNewline -ForegroundColor Red; Write-Host $Message; exit 1 }

function Show-Help {
    Write-Host @"
Agent Bootstrap

Usage:
  `$env:AGENT='codex'; `$env:AGENT_TOKEN='...'; `$env:AGENT_BASE_URL='...'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
  `$env:AGENT='claudecode'; `$env:AGENT_TOKEN='...'; `$env:AGENT_BASE_URL='...'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
  `$env:AGENT='openclaw'; `$env:AGENT_TOKEN='...'; `$env:AGENT_BASE_URL='...'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
  `$env:AGENT='codexplusplus'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex

Aliases:
  codex, claudecode, claude, openclaw, codexplusplus, codex++, cpp

Unified env:
  AGENT_TOKEN      Shared API token for the selected agent
  AGENT_BASE_URL   Shared gateway/base URL for the selected agent
  AGENT_MODEL      Optional model value for agents that support it
  CODEX_PLUS_PLUS_REF  Optional upstream Codex++ ref/tag (default: v1.0.7)
"@
}

function Normalize-Agent {
    param([string]$Name)
    switch ($Name.ToLowerInvariant()) {
        "codex" { return "codex" }
        "openai-codex" { return "codex" }
        "claude" { return "claudecode" }
        "claudecode" { return "claudecode" }
        "claude-code" { return "claudecode" }
        "openclaw" { return "openclaw" }
        "claw" { return "openclaw" }
        "codexplusplus" { return "codexplusplus" }
        "codex-plus-plus" { return "codexplusplus" }
        "codex++" { return "codexplusplus" }
        "cpp" { return "codexplusplus" }
        default { Fail "Unknown agent: $Name" }
    }
}

function Set-AgentEnv {
    param([string]$Normalized)
    switch ($Normalized) {
        "codex" {
            if ($env:AGENT_TOKEN -and -not $env:CODEX_TOKEN) { $env:CODEX_TOKEN = $env:AGENT_TOKEN }
            if ($env:AGENT_BASE_URL -and -not $env:CODEX_API_URL) { $env:CODEX_API_URL = $env:AGENT_BASE_URL }
            if ($env:AGENT_MODEL -and -not $env:CODEX_MODEL) { $env:CODEX_MODEL = $env:AGENT_MODEL }
        }
        "claudecode" {
            if ($env:AGENT_TOKEN -and -not $env:CLAUDE_TOKEN) { $env:CLAUDE_TOKEN = $env:AGENT_TOKEN }
            if ($env:AGENT_TOKEN -and -not $env:CLAUDE_CLIENT_TOKEN) { $env:CLAUDE_CLIENT_TOKEN = $env:AGENT_TOKEN }
            if ($env:AGENT_BASE_URL -and -not $env:CLAUDE_API_URL) { $env:CLAUDE_API_URL = $env:AGENT_BASE_URL }
        }
        "openclaw" {
            if ($env:AGENT_TOKEN -and -not $env:OPENCLAW_TOKEN) { $env:OPENCLAW_TOKEN = $env:AGENT_TOKEN }
            if ($env:AGENT_BASE_URL -and -not $env:OPENCLAW_BASE_URL) { $env:OPENCLAW_BASE_URL = $env:AGENT_BASE_URL }
            if ($env:AGENT_MODEL -and -not $env:OPENCLAW_MODEL) { $env:OPENCLAW_MODEL = $env:AGENT_MODEL }
        }
    }
}

function Assert-AgentEnv {
    param([string]$Normalized)
    switch ($Normalized) {
        "codex" {
            if ((-not $env:CODEX_TOKEN) -and (-not $env:OPENAI_API_KEY)) { Fail "Missing AGENT_TOKEN, CODEX_TOKEN, or OPENAI_API_KEY." }
            if ((-not $env:CODEX_API_URL) -and (-not $env:OPENAI_BASE_URL)) { Fail "Missing AGENT_BASE_URL, CODEX_API_URL, or OPENAI_BASE_URL." }
        }
        "claudecode" {
            if ((-not $env:CLAUDE_TOKEN) -and (-not $env:CLAUDE_CLIENT_TOKEN)) { Fail "Missing AGENT_TOKEN, CLAUDE_TOKEN, or CLAUDE_CLIENT_TOKEN." }
            if (-not $env:CLAUDE_API_URL) { Fail "Missing AGENT_BASE_URL or CLAUDE_API_URL." }
        }
        "openclaw" {
            if (-not $env:OPENCLAW_TOKEN) { Fail "Missing AGENT_TOKEN or OPENCLAW_TOKEN." }
            if ((-not $env:OPENCLAW_BASE_URL) -and (-not $env:OPENCLAW_API_URL)) { Fail "Missing AGENT_BASE_URL, OPENCLAW_BASE_URL, or OPENCLAW_API_URL." }
        }
        "codexplusplus" {
        }
    }
}

function Get-SourceDir {
    if ($LocalSource) {
        if (-not (Test-Path $LocalSource)) { Fail "Local source not found: $LocalSource" }
        return (Resolve-Path $LocalSource).Path
    }

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-bootstrap-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $zip = Join-Path $tmp "bootstrap.zip"
    $urls = @(
        "https://codeload.github.com/$BootstrapRepo/zip/refs/heads/$BootstrapRef",
        "https://codeload.github.com/$BootstrapRepo/zip/refs/tags/$BootstrapRef",
        "https://github.com/$BootstrapRepo/archive/$BootstrapRef.zip"
    )
    Write-Info "Downloading agent bootstrap assets from $BootstrapRepo@$BootstrapRef"
    $downloaded = $false
    foreach ($url in $urls) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
            Expand-Archive -Path $zip -DestinationPath $tmp -Force
            $downloaded = $true
            break
        } catch {
            Remove-Item -Path $zip -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path $tmp -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $downloaded) { Fail "Failed to download a valid bootstrap archive from $BootstrapRepo@$BootstrapRef" }
    $child = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
    if (-not $child) { Fail "Unable to expand bootstrap assets" }
    return $child.FullName
}

function Main {
    Write-Host ""
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "| Agent Bootstrap                                 |" -ForegroundColor Cyan
    Write-Host "| codex / claudecode / openclaw / codex++        |" -ForegroundColor Cyan
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    if ($Help) { Show-Help; return }
    if (-not $Agent) {
        Show-Help
        Fail "Missing AGENT. Set `$env:AGENT to codex, claudecode, openclaw, or codexplusplus."
    }

    $normalized = Normalize-Agent $Agent
    Set-AgentEnv $normalized
    Assert-AgentEnv $normalized
    $sourceDir = Get-SourceDir
    $installer = Join-Path $sourceDir "agents\$normalized\install.ps1"
    if (-not (Test-Path $installer)) { Fail "Installer not found: $installer" }
    Write-Ok "Selected agent: $normalized"
    if ($normalized -eq "codex") {
        & $installer -LocalSource $sourceDir
    } else {
        & $installer
    }
}

Main
