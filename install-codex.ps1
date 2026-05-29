# Minimal stable Codex entrypoint for Windows PowerShell.
# Downloads this repo at a fixed ref and runs the Codex-only installer.

param(
    [string]$BootstrapRepo = $(if ($env:BOOTSTRAP_REPO) { $env:BOOTSTRAP_REPO } else { "HY-LiYihan/agent-bootstrap" }),
    [string]$BootstrapRef = $(if ($env:BOOTSTRAP_REF) { $env:BOOTSTRAP_REF } else { "stable" }),
    [string]$LocalSource = $(if ($env:AGENT_BOOTSTRAP_LOCAL_SOURCE) { $env:AGENT_BOOTSTRAP_LOCAL_SOURCE } else { "" }),
    [string]$Restore = "",
    [switch]$DryRun,
    [switch]$SkipCodexInstall,
    [switch]$SkipProfileUpdate,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Write-Info { param([string]$Message) Write-Host "[INFO] " -NoNewline -ForegroundColor Blue; Write-Host $Message }
function Write-Ok { param([string]$Message) Write-Host "[OK] " -NoNewline -ForegroundColor Green; Write-Host $Message }
function Fail { param([string]$Message) Write-Host "[ERROR] " -NoNewline -ForegroundColor Red; Write-Host $Message; exit 1 }

function Show-Help {
    Write-Host @"
Codex Stable Bootstrap for Windows

Usage:
  `$env:CODEX_TOKEN='YOUR_TOKEN'; `$env:CODEX_API_URL='YOUR_BASE_URL'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install-codex.ps1 | iex

All other options should be set through CODEX_* environment variables and are passed to agents/codex/install.ps1.
"@
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

    Write-Info "Downloading Codex bootstrap assets from $BootstrapRepo@$BootstrapRef"
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
    if ($Help) { Show-Help; return }
    Write-Host ""
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "| Codex Stable Bootstrap                         |" -ForegroundColor Cyan
    Write-Host "| minimal custom-provider setup                  |" -ForegroundColor Cyan
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    $sourceDir = Get-SourceDir
    $installer = Join-Path $sourceDir "agents\codex\install.ps1"
    if (-not (Test-Path $installer)) { Fail "Codex installer not found: $installer" }
    Write-Ok "Selected stable agent: codex"
    & $installer `
        -LocalSource $sourceDir `
        -Restore $Restore `
        -DryRun:$DryRun `
        -SkipCodexInstall:$SkipCodexInstall `
        -SkipProfileUpdate:$SkipProfileUpdate
}

Main
