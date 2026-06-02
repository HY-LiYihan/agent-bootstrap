# Claude Code bootstrap for Windows PowerShell.
param(
    [string]$Token = $(if ($env:CLAUDE_CLIENT_TOKEN) { $env:CLAUDE_CLIENT_TOKEN } elseif ($env:CLAUDE_TOKEN) { $env:CLAUDE_TOKEN } else { "" }),
    [string]$BaseUrl = $(if ($env:CLAUDE_API_URL) { $env:CLAUDE_API_URL } else { "" }),
    [string]$Model = $(if ($env:CLAUDE_MODEL) { $env:CLAUDE_MODEL } elseif ($env:ANTHROPIC_MODEL) { $env:ANTHROPIC_MODEL } elseif ($env:AGENT_MODEL) { $env:AGENT_MODEL } else { "" }),
    [string]$ClaudeHome = $(if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE ".claude" }),
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipInstall,
    [switch]$NoBun
)

$ErrorActionPreference = "Stop"
$SettingsFile = Join-Path $ClaudeHome "settings.json"
$ClaudeJsonFile = Join-Path $env:USERPROFILE ".claude.json"

function Write-Step { param([string]$Step,[string]$Message) Write-Host ""; Write-Host "[$Step] " -NoNewline -ForegroundColor Magenta; Write-Host $Message -ForegroundColor White }
function Write-Ok { param([string]$Message) Write-Host "[OK] " -NoNewline -ForegroundColor Green; Write-Host $Message }
function Write-Info { param([string]$Message) Write-Host "[INFO] " -NoNewline -ForegroundColor Blue; Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Host "[WARN] " -NoNewline -ForegroundColor Yellow; Write-Host $Message }
function Fail { param([string]$Message) Write-Host "[ERROR] " -NoNewline -ForegroundColor Red; Write-Host $Message; exit 1 }
function Invoke-Run { param([string]$Description,[scriptblock]$Action) if ($DryRun) { Write-Host "DRY-RUN: $Description" } else { & $Action } }
function Test-CommandExists { param([string]$Command) return [bool](Get-Command $Command -ErrorAction SilentlyContinue) }
function Mask-Secret { param([string]$Value) if (-not $Value) { return "<missing>" }; if ($Value.Length -le 8) { return "<hidden>" }; return "$($Value.Substring(0,4))...$($Value.Substring($Value.Length-4))" }
function Mask-Url { param([string]$Value) if ($Value) { return "<configured>" } return "<missing>" }
function Backup-File { param([string]$Path) if (Test-Path $Path) { $backup = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"; Invoke-Run "backup $Path" { Copy-Item $Path $backup -Force }; Write-Ok "Backup created: $backup" } }

function Assert-RequiredInputs {
    if (-not $Token) { Fail "Missing CLAUDE_CLIENT_TOKEN or CLAUDE_TOKEN" }
    if (-not $BaseUrl) { Fail "Missing CLAUDE_API_URL" }
}

function Install-Claude {
    if ($SkipInstall) { Write-Info "Skipping Claude Code install"; return }
    if ((Test-CommandExists "claude") -and (-not $Force)) { Write-Ok "Claude already installed: $((Get-Command claude).Source)"; return }
    if ($DryRun) { Invoke-Run "irm https://claude.ai/install.ps1 | iex" { irm https://claude.ai/install.ps1 | iex }; return }

    try {
        Write-Info "Trying official Claude Code installer"
        irm https://claude.ai/install.ps1 | iex
        if (Test-CommandExists "claude") { Write-Ok "Claude Code installed"; return }
    } catch {
        Write-Warn "Official installer failed: $_"
    }

    if ($NoBun) { Fail "Claude installer failed and -NoBun was set" }
    if (-not (Test-CommandExists "bun")) {
        Write-Info "Installing Bun runtime"
        powershell -NoProfile -ExecutionPolicy Bypass -Command "irm bun.sh/install.ps1 | iex"
        $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
        if (Test-Path $bunBin) { $env:Path = "$bunBin;$env:Path" }
    }
    & bun install -g '@anthropic-ai/claude-code'
}

function Write-ClaudeSettings {
    Assert-RequiredInputs
    Invoke-Run "create $ClaudeHome" { New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null }
    Backup-File $SettingsFile
    Backup-File $ClaudeJsonFile
    if ($DryRun) {
        Write-Info "Would write Claude settings with token $(Mask-Secret $Token)"
        if ($Model) { Write-Info "Would set Claude default model: $Model" }
        return
    }

    $settings = @{}
    if (Test-Path $SettingsFile) {
        Write-Warn "Existing settings.json was backed up and will be rewritten for Windows PowerShell compatibility"
    }
    $settings.env = @{}
    $settings.env.ANTHROPIC_AUTH_TOKEN = $Token
    $settings.env.ANTHROPIC_BASE_URL = $BaseUrl
    if ($Model) {
        $settings.model = $Model
        $settings.env.ANTHROPIC_MODEL = $Model
    }
    $settings.env.API_TIMEOUT_MS = 600000
    $settings.env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE = "1"
    $settings.env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
    if (-not $settings.permissions) { $settings.permissions = @{ allow = @(); deny = @() } }
    [System.IO.File]::WriteAllText($SettingsFile, ($settings | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))

    $claudeJson = @{}
    $claudeJson.hasCompletedOnboarding = $true
    [System.IO.File]::WriteAllText($ClaudeJsonFile, ($claudeJson | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
    [System.Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $Token, [System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $BaseUrl, [System.EnvironmentVariableTarget]::User)
    if ($Model) { [System.Environment]::SetEnvironmentVariable("ANTHROPIC_MODEL", $Model, [System.EnvironmentVariableTarget]::User) }
    Write-Ok "Claude settings configured: $SettingsFile"
}

Write-Host ""
Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "| Claude Code Bootstrap                           |" -ForegroundColor Cyan
Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
Write-Step "1/7" "Inspect Claude Code settings"
Write-Info "API URL: $(Mask-Url $BaseUrl)"
if ($Model) { Write-Info "Model: $Model" }
if ($Token) { Write-Info "Token: $(Mask-Secret $Token)" }
Assert-RequiredInputs
Write-Step "2/7" "Verify config directories"
Write-Info "Claude home: $ClaudeHome"
Write-Step "3/7" "Install or verify Claude Code CLI"
Install-Claude
Write-Step "4/7" "Write Claude credentials and API URL"
Write-ClaudeSettings
Write-Step "5/7" "Write onboarding marker"
Write-Ok "Onboarding marker handled via $ClaudeJsonFile"
Write-Step "6/7" "Ensure user environment is set"
Write-Ok "ANTHROPIC_AUTH_TOKEN and ANTHROPIC_BASE_URL configured"
Write-Step "7/7" "Finish"
Write-Ok "Claude Code bootstrap completed"
Write-Info "Try: claude"
