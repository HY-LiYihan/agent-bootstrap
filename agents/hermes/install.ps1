# Hermes Agent bootstrap for Windows PowerShell.
param(
    [string]$Token = $(if ($env:HERMES_API_KEY) { $env:HERMES_API_KEY } elseif ($env:HERMES_TOKEN) { $env:HERMES_TOKEN } elseif ($env:OPENAI_API_KEY) { $env:OPENAI_API_KEY } elseif ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } else { "" }),
    [string]$BaseUrl = $(if ($env:HERMES_BASE_URL) { $env:HERMES_BASE_URL } elseif ($env:OPENAI_BASE_URL) { $env:OPENAI_BASE_URL } elseif ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } else { "" }),
    [string]$Model = $(if ($env:HERMES_MODEL) { $env:HERMES_MODEL } elseif ($env:AGENT_MODEL) { $env:AGENT_MODEL } else { "gpt-5.5" }),
    [string]$HermesHome = $(if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $env:USERPROFILE ".hermes" }),
    [string]$InstallRef = $(if ($env:HERMES_INSTALL_REF) { $env:HERMES_INSTALL_REF } else { "main" }),
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$ConfigFile = Join-Path $HermesHome "config.yaml"
$EnvFile = Join-Path $HermesHome ".env"

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
    if (-not $Token) { Fail "Missing HERMES_API_KEY, HERMES_TOKEN, OPENAI_API_KEY, or AGENT_TOKEN" }
    if (-not $BaseUrl) { Fail "Missing HERMES_BASE_URL, OPENAI_BASE_URL, or AGENT_BASE_URL" }
    if (-not $Model) { Fail "Missing HERMES_MODEL or AGENT_MODEL" }
}

function Install-Hermes {
    if ($SkipInstall) { Write-Info "Skipping Hermes install"; return }
    if ((Test-CommandExists "hermes") -and (-not $Force)) { Write-Ok "Hermes already installed: $((Get-Command hermes).Source)"; return }
    if (Test-CommandExists "pipx") {
        Invoke-Run "pipx install Hermes Agent" { pipx install --force "git+https://github.com/NousResearch/hermes-agent.git@$InstallRef" }
        return
    }
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $python) { Fail "Python or pipx is required for Hermes install" }
    Invoke-Run "python -m pip install Hermes Agent" { & $python.Source -m pip install --user --upgrade "git+https://github.com/NousResearch/hermes-agent.git@$InstallRef" }
}

function Write-HermesConfig {
    Assert-RequiredInputs
    Invoke-Run "create $HermesHome" { New-Item -ItemType Directory -Path $HermesHome -Force | Out-Null }
    Backup-File $ConfigFile
    Backup-File $EnvFile
    if ($DryRun) {
        Write-Info "Would write Hermes config to $ConfigFile"
        Write-Info "Would write Hermes env to $EnvFile with token $(Mask-Secret $Token)"
        return
    }

    $envText = @"
OPENAI_API_KEY=$Token
OPENAI_BASE_URL=$BaseUrl
HERMES_API_KEY=$Token
HERMES_BASE_URL=$BaseUrl
"@
    [System.IO.File]::WriteAllText($EnvFile, $envText, [System.Text.UTF8Encoding]::new($false))

    $configText = @"
model:
  provider: "custom"
  default: "$Model"
  base_url: "$BaseUrl"

terminal:
  backend: "local"
"@
    [System.IO.File]::WriteAllText($ConfigFile, $configText, [System.Text.UTF8Encoding]::new($false))
    Write-Ok "Hermes config ready: $ConfigFile"
    Write-Ok "Hermes env ready: $EnvFile"
}

Write-Host ""
Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "| Hermes Agent Bootstrap                          |" -ForegroundColor Cyan
Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
Write-Step "1/5" "Inspect Hermes settings"
Write-Info "Hermes home: $HermesHome"
Write-Info "Base URL: $(Mask-Url $BaseUrl)"
Write-Info "Model: $Model"
if ($Token) { Write-Info "Token: $(Mask-Secret $Token)" }
Assert-RequiredInputs
Write-Step "2/5" "Install or verify Hermes CLI"
Install-Hermes
Write-Step "3/5" "Write Hermes API and model config"
Write-HermesConfig
Write-Step "4/5" "Check Hermes command"
if (Test-CommandExists "hermes") { Write-Ok "Hermes command available: $((Get-Command hermes).Source)" } else { Write-Warn "Hermes command not on PATH yet; restart PowerShell or check Python user scripts path" }
Write-Step "5/5" "Finish"
Write-Ok "Hermes Agent bootstrap completed"
Write-Info "Try: hermes"
