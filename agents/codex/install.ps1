# Codex Bootstrap for Windows PowerShell
# Usage: $env:CODEX_TOKEN='YOUR_TOKEN'; $env:CODEX_API_URL='https://gateway.example.com/v1'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex

param(
    [string]$Token = $(if ($env:CODEX_TOKEN) { $env:CODEX_TOKEN } else { $env:OPENAI_API_KEY }),
    [string]$BaseUrl = $(if ($env:CODEX_API_URL) { $env:CODEX_API_URL } elseif ($env:OPENAI_BASE_URL) { $env:OPENAI_BASE_URL } else { "" }),
    [string]$ProviderId = "custom",
    [string]$ProviderEnvKey = $(if ($env:CODEX_PROVIDER_ENV_KEY) { $env:CODEX_PROVIDER_ENV_KEY } else { "CODEX_API_KEY" }),
    [string]$Model = $(if ($env:CODEX_MODEL) { $env:CODEX_MODEL } else { "gpt-5.5" }),
    [string]$ReasoningEffort = $(if ($env:CODEX_REASONING_EFFORT) { $env:CODEX_REASONING_EFFORT } else { "high" }),
    [string]$ModelVerbosity = $(if ($env:CODEX_MODEL_VERBOSITY) { $env:CODEX_MODEL_VERBOSITY } else { "medium" }),
    [string]$ReasoningSummary = $(if ($env:CODEX_REASONING_SUMMARY) { $env:CODEX_REASONING_SUMMARY } else { "auto" }),
    [string]$WebSearch = $(if ($env:CODEX_WEB_SEARCH) { $env:CODEX_WEB_SEARCH } else { "live" }),
    [int]$ProjectDocMaxBytes = $(if ($env:CODEX_PROJECT_DOC_MAX_BYTES) { [int]$env:CODEX_PROJECT_DOC_MAX_BYTES } else { 65536 }),
    [int]$AgentsMaxThreads = $(if ($env:CODEX_AGENTS_MAX_THREADS) { [int]$env:CODEX_AGENTS_MAX_THREADS } else { 10 }),
    [int]$AgentsMaxDepth = $(if ($env:CODEX_AGENTS_MAX_DEPTH) { [int]$env:CODEX_AGENTS_MAX_DEPTH } else { 1 }),
    [int]$AgentsJobMaxRuntimeSeconds = $(if ($env:CODEX_AGENTS_JOB_MAX_RUNTIME_SECONDS) { [int]$env:CODEX_AGENTS_JOB_MAX_RUNTIME_SECONDS } else { 1800 }),
    [int]$RequestMaxRetries = $(if ($env:CODEX_REQUEST_MAX_RETRIES) { [int]$env:CODEX_REQUEST_MAX_RETRIES } else { 4 }),
    [int]$StreamMaxRetries = $(if ($env:CODEX_STREAM_MAX_RETRIES) { [int]$env:CODEX_STREAM_MAX_RETRIES } else { 5 }),
    [int]$StreamIdleTimeoutMs = $(if ($env:CODEX_STREAM_IDLE_TIMEOUT_MS) { [int]$env:CODEX_STREAM_IDLE_TIMEOUT_MS } else { 300000 }),
    [string]$SecurityProfile = $(if ($env:CODEX_SECURITY_PROFILE) { $env:CODEX_SECURITY_PROFILE } else { "max" }),
    [string]$NpmRegistry = $(if ($env:CODEX_NPM_REGISTRY) { $env:CODEX_NPM_REGISTRY } else { "https://registry.npmmirror.com" }),
    [string]$BootstrapRepo = $(if ($env:BOOTSTRAP_REPO) { $env:BOOTSTRAP_REPO } else { "HY-LiYihan/agent-bootstrap" }),
    [string]$BootstrapRef = $(if ($env:BOOTSTRAP_REF) { $env:BOOTSTRAP_REF } else { "stable" }),
    [string]$Profile = $(if ($env:CODEX_PROFILE) { $env:CODEX_PROFILE } else { "default" }),
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [string]$ProjectDir = $(if ($env:CODEX_PROJECT_DIR) { $env:CODEX_PROJECT_DIR } else { (Get-Location).Path }),
    [string]$BackupDir = $(if ($env:CODEX_INSTALL_BACKUP_DIR) { $env:CODEX_INSTALL_BACKUP_DIR } else { "" }),
    [string]$Restore = "",
    [string]$LocalSource = "",
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$Force,
    [switch]$SkipCodexInstall,
    [switch]$SkipProfileUpdate,
    [switch]$SkipSmokeTest,
    [switch]$SmokeTest,
    [string]$SmokeTestPrompt = $(if ($env:CODEX_SMOKE_TEST_PROMPT) { $env:CODEX_SMOKE_TEST_PROMPT } else { "你好" }),
    [int]$SmokeTestTimeoutSeconds = $(if ($env:CODEX_SMOKE_TEST_TIMEOUT_SECONDS) { [int]$env:CODEX_SMOKE_TEST_TIMEOUT_SECONDS } else { 120 }),
    [switch]$NoBun,
    [switch]$NoInstallBackup,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ConfigFile = Join-Path $CodexHome "config.toml"
$PrivateEnvFile = $(if ($env:CODEX_PRIVATE_ENV_FILE) { $env:CODEX_PRIVATE_ENV_FILE } else { Join-Path $CodexHome "private.env" })
$RunSmokeTest = $true
if ($env:CODEX_SMOKE_TEST -and $env:CODEX_SMOKE_TEST.ToLowerInvariant() -in @("0", "false", "no", "off")) { $RunSmokeTest = $false }
if ($env:CODEX_SMOKE_TEST -and $env:CODEX_SMOKE_TEST.ToLowerInvariant() -in @("1", "true", "yes", "on")) { $RunSmokeTest = $true }
if ($SkipSmokeTest) { $RunSmokeTest = $false }
if ($SmokeTest) { $RunSmokeTest = $true }

function Write-Banner {
    Write-Host ""
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "| " -NoNewline -ForegroundColor Cyan
    Write-Host "Codex Bootstrap" -NoNewline -ForegroundColor White
    Write-Host "                                 |" -ForegroundColor Cyan
    Write-Host "| custom provider + Windows setup                 |" -ForegroundColor Cyan
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step { param([string]$Step, [string]$Message) Write-Host ""; Write-Host "[$Step] " -NoNewline -ForegroundColor Magenta; Write-Host $Message -ForegroundColor White }
function Write-Ok { param([string]$Message) Write-Host "[OK] " -NoNewline -ForegroundColor Green; Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Host "[WARN] " -NoNewline -ForegroundColor Yellow; Write-Host $Message }
function Write-Info { param([string]$Message) Write-Host "[INFO] " -NoNewline -ForegroundColor Blue; Write-Host $Message }
function Fail { param([string]$Message) Write-Host "[ERROR] " -NoNewline -ForegroundColor Red; Write-Host $Message; exit 1 }

function Show-Help {
    Write-Host @"
Codex Bootstrap for Windows

Usage:
  `$env:CODEX_TOKEN='YOUR_TOKEN'; `$env:CODEX_API_URL='https://gateway.example.com/v1'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex

Environment:
  CODEX_TOKEN or OPENAI_API_KEY       API key written to the provider env key
  CODEX_API_URL or OPENAI_BASE_URL    API base URL written to [model_providers.custom]
  CODEX_PROVIDER_ENV_KEY              Provider env key (default: CODEX_API_KEY)
  CODEX_MODEL                         Default model (default: gpt-5.5)
  CODEX_REASONING_EFFORT              Reasoning effort (default: high)
  CODEX_MODEL_VERBOSITY               Model verbosity (default: medium)
  CODEX_REASONING_SUMMARY             Reasoning summary (default: auto)
  CODEX_WEB_SEARCH                    Web search mode (default: live)
  CODEX_SECURITY_PROFILE              max or safe (default: max)
  CODEX_INSTALL_BACKUP_DIR            Optional explicit restore snapshot directory
  CODEX_SMOKE_TEST                    1 or 0; run codex exec reply test after install (default: 1)
  CODEX_SMOKE_TEST_PROMPT             Prompt for final reply test (default: 你好)
  CODEX_SMOKE_TEST_TIMEOUT_SECONDS    Timeout for final reply test (default: 120)
  CODEX_NPM_REGISTRY                  npm fallback registry (default: https://registry.npmmirror.com)
  BOOTSTRAP_REF                       Git branch/tag for templates (default: stable)
"@
}

function Invoke-Run {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) {
        Write-Host "DRY-RUN: $Description"
    } else {
        & $Action
    }
}

function Mask-Secret {
    param([string]$Value)
    if (-not $Value) { return "<missing>" }
    if ($Value.Length -le 8) { return "<hidden>" }
    return "$($Value.Substring(0, 4))...$($Value.Substring($Value.Length - 4))"
}

function Escape-TomlString {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Escape-PowerShellSingleQuotedString {
    param([string]$Value)
    return $Value.Replace("'", "''")
}

function Assert-EnvKey {
    if ($ProviderEnvKey -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Fail "Invalid CODEX_PROVIDER_ENV_KEY: $ProviderEnvKey"
    }
}

function Assert-RequiredInputs {
    if (-not $Token) { Fail "Missing CODEX_TOKEN or OPENAI_API_KEY" }
    if (-not $BaseUrl) { Fail "Missing CODEX_API_URL or OPENAI_BASE_URL" }
    if ($SmokeTestTimeoutSeconds -le 0) { Fail "CODEX_SMOKE_TEST_TIMEOUT_SECONDS must be greater than 0" }
    switch ($SecurityProfile.ToLowerInvariant()) {
        { $_ -in @("max", "full", "full-auto", "danger") } { $script:SecurityProfile = "max"; break }
        { $_ -in @("safe", "official", "default") } { $script:SecurityProfile = "safe"; break }
        default { Fail "Invalid CODEX_SECURITY_PROFILE: $SecurityProfile. Use max or safe." }
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
    Write-Info "Downloading bootstrap assets from $BootstrapRepo@$BootstrapRef"
    Invoke-Run "download and expand bootstrap archive" {
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
    }
    if ($DryRun) { return $tmp }
    $child = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
    if (-not $child) { Fail "Unable to expand bootstrap assets" }
    return $child.FullName
}

function Load-Profile {
    param([string]$SourceDir)
    $profileFile = Join-Path $SourceDir "profiles\$Profile.env"
    if (-not (Test-Path $profileFile)) {
        Write-Warn "Profile not found: $Profile; using built-in defaults"
        return
    }

    $content = Get-Content $profileFile -Raw
    if ($content -match 'CODEX_MODEL:=([^}\"]+)') { $script:Model = $Matches[1] }
    if ($content -match 'CODEX_REASONING_EFFORT:=([^}\"]+)') { $script:ReasoningEffort = $Matches[1] }
    Write-Ok "Loaded profile: $Profile"
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Ensure-Bun {
    if (Test-CommandExists "bun") {
        $version = (& bun --version 2>$null)
        Write-Ok "Bun found: v$version"
        return $true
    }
    if ($NoBun) { return $false }
    Write-Info "Installing Bun with the official PowerShell installer"
    Invoke-Run "install Bun" { powershell -NoProfile -ExecutionPolicy Bypass -Command "irm bun.sh/install.ps1 | iex" }
    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    if (Test-Path $bunBin) { $env:Path = "$bunBin;$env:Path" }
    return (Test-CommandExists "bun")
}

function Install-Codex {
    if ($SkipCodexInstall) {
        Write-Info "Skipping Codex install"
        return
    }
    if ((Test-CommandExists "codex") -and (-not $Force)) {
        Write-Ok "Codex already installed: $((Get-Command codex).Source)"
        return
    }

    if (Ensure-Bun) {
        Invoke-Run "bun install -g @openai/codex" { & bun install -g '@openai/codex' }
        return
    }

    if (-not (Test-CommandExists "npm")) {
        Fail "npm is required when Bun is unavailable. Install Node.js or rerun without -NoBun."
    }
    if ($DryRun) {
        Invoke-Run "npm install -g @openai/codex" { & npm install -g '@openai/codex' }
        return
    }

    try {
        & npm install -g '@openai/codex'
        if ($LASTEXITCODE -eq 0) { return }
        throw "npm install exited with $LASTEXITCODE"
    } catch {
        Write-Warn "npm default registry install failed; retrying with $NpmRegistry"
        & npm install -g '@openai/codex' "--registry=$NpmRegistry"
    }
}

function Backup-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $backup = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Invoke-Run "copy $Path to $backup" { Copy-Item -Path $Path -Destination $backup -Force }
    Write-Ok "Backup created: $backup"
}

function Copy-IfExists {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path $Source)) { return }
    $dir = Split-Path $Destination
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Copy-Item -Path $Source -Destination $Destination -Force
}

function New-InstallBackup {
    if ($NoInstallBackup) { return }
    Write-Step "Safety" "Create pre-install restore snapshot"
    if ($DryRun) {
        Write-Host "DRY-RUN: create restore snapshot for $CodexHome and $ProjectDir"
        return
    }

    $backupRoot = if ($BackupDir) { $BackupDir } else { Join-Path $CodexHome ("backups_state\install\" + (Get-Date -Format "yyyyMMddHHmmss")) }
    New-Item -ItemType Directory -Path (Join-Path $backupRoot "codex") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $backupRoot "project") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $backupRoot "profile") -Force | Out-Null

    $manifest = @(
        "created_at=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
        "codex_home=$CodexHome",
        "project_dir=$ProjectDir",
        "powershell_profile=$PROFILE",
        "restore_hint=agents\codex\install.ps1 -Restore `"$backupRoot`""
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $backupRoot "MANIFEST.txt"), $manifest + "`n", [System.Text.UTF8Encoding]::new($false))

    Copy-IfExists $ConfigFile (Join-Path $backupRoot "codex\config.toml")
    Copy-IfExists $PrivateEnvFile (Join-Path $backupRoot "codex\private.env")
    Copy-IfExists (Join-Path $CodexHome "rules\default.rules") (Join-Path $backupRoot "codex\rules\default.rules")
    Copy-IfExists (Join-Path $CodexHome "state_5.sqlite") (Join-Path $backupRoot "codex\state_5.sqlite")
    Copy-IfExists (Join-Path $ProjectDir "AGENTS.md") (Join-Path $backupRoot "project\AGENTS.md")
    Copy-IfExists $PROFILE (Join-Path $backupRoot ("profile\" + (Split-Path $PROFILE -Leaf)))

    New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $CodexHome ".last-install-backup"), $backupRoot + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Ok "Restore snapshot created: $backupRoot"
    Write-Info "Restore with: .\agents\codex\install.ps1 -Restore `"$backupRoot`""
}

function Restore-InstallBackup {
    param([string]$BackupRoot)
    if (-not (Test-Path $BackupRoot)) { Fail "Restore backup not found: $BackupRoot" }
    Write-Step "Restore" "Restore Codex files from $BackupRoot"
    Invoke-Run "create restore target directories" {
        New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $CodexHome "rules") -Force | Out-Null
        New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
    }
    $items = @(
        @((Join-Path $BackupRoot "codex\config.toml"), $ConfigFile),
        @((Join-Path $BackupRoot "codex\private.env"), $PrivateEnvFile),
        @((Join-Path $BackupRoot "codex\rules\default.rules"), (Join-Path $CodexHome "rules\default.rules")),
        @((Join-Path $BackupRoot "project\AGENTS.md"), (Join-Path $ProjectDir "AGENTS.md"))
    )
    foreach ($item in $items) {
        if (Test-Path $item[0]) {
            Invoke-Run "restore $($item[1])" { Copy-Item -Path $item[0] -Destination $item[1] -Force }
        }
    }
    $stateBackup = Join-Path $BackupRoot "codex\state_5.sqlite"
    $stateDest = Join-Path $CodexHome "state_5.sqlite"
    if (Test-Path $stateBackup) {
        Invoke-Run "restore $stateDest" {
            Remove-Item -Path "$stateDest-wal", "$stateDest-shm" -Force -ErrorAction SilentlyContinue
            Copy-Item -Path $stateBackup -Destination $stateDest -Force
        }
    }
    Write-Ok "Restore completed from: $BackupRoot"
}

function Write-PrivateEnv {
    if (-not $Token) { Fail "Missing CODEX_TOKEN or OPENAI_API_KEY" }
    Write-Info "Secret file: $PrivateEnvFile"
    Write-Info "Provider env key: $ProviderEnvKey"
    Invoke-Run "create $CodexHome" { New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null }
    $tokenEscaped = Escape-PowerShellSingleQuotedString $Token
    $content = "# Managed by agent-bootstrap. Do not commit this file.`n`$" + "env:$ProviderEnvKey = '$tokenEscaped'`n"
    Invoke-Run "write $ProviderEnvKey to $PrivateEnvFile" { [System.IO.File]::WriteAllText($PrivateEnvFile, $content, [System.Text.UTF8Encoding]::new($false)) }
    Invoke-Run "set user environment variable $ProviderEnvKey" { [System.Environment]::SetEnvironmentVariable($ProviderEnvKey, $Token, [System.EnvironmentVariableTarget]::User) }
    Invoke-Run "set current session environment variable $ProviderEnvKey" { Set-Item -Path "Env:$ProviderEnvKey" -Value $Token }
    Write-Ok "Private env and user environment are ready"
}

function Write-CodexConfig {
    Invoke-Run "create $CodexHome" { New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null }
    Backup-File $ConfigFile

    $provider = Escape-TomlString $ProviderId
    $envKey = Escape-TomlString $ProviderEnvKey
    $modelEscaped = Escape-TomlString $Model
    $effort = Escape-TomlString $ReasoningEffort
    $verbosity = Escape-TomlString $ModelVerbosity
    $summary = Escape-TomlString $ReasoningSummary
    $webSearchEscaped = Escape-TomlString $WebSearch
    $url = Escape-TomlString $BaseUrl
    $preserveTail = ""
    if (Test-Path $ConfigFile) {
        $lines = Get-Content $ConfigFile
        $start = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\[marketplaces' -or $lines[$i] -match '^\[plugins') {
                $start = $i
                break
            }
        }
        if ($start -ge 0) {
            $preserveTail = ($lines[$start..($lines.Count - 1)] -join "`n")
        }
    }

    if ($SecurityProfile -eq "max") {
        $config = @"
# Managed by agent-bootstrap.
# This intentionally uses a custom provider, matching the simple gateway-oriented Codex setup.
model = "$modelEscaped"
model_reasoning_effort = "$effort"
model_verbosity = "$verbosity"
model_reasoning_summary = "$summary"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "$provider"
web_search = "$webSearchEscaped"
project_doc_max_bytes = $ProjectDocMaxBytes
approval_policy = "never"
sandbox_mode = "danger-full-access"
windows_wsl_setup_acknowledged = true

[agents]
max_threads = $AgentsMaxThreads
max_depth = $AgentsMaxDepth
job_max_runtime_seconds = $AgentsJobMaxRuntimeSeconds

[model_providers."$provider"]
name = "$provider"
base_url = "$url"
wire_api = "responses"
env_key = "$envKey"
request_max_retries = $RequestMaxRetries
stream_max_retries = $StreamMaxRetries
stream_idle_timeout_ms = $StreamIdleTimeoutMs
"@
    } else {
        $config = @"
# Managed by agent-bootstrap.
# Safe profile: leaves high-permission controls at Codex defaults.
model = "$modelEscaped"
model_reasoning_effort = "$effort"
model_verbosity = "$verbosity"
model_reasoning_summary = "$summary"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "$provider"
web_search = "$webSearchEscaped"
project_doc_max_bytes = $ProjectDocMaxBytes
windows_wsl_setup_acknowledged = true

[agents]
max_threads = $AgentsMaxThreads
max_depth = $AgentsMaxDepth
job_max_runtime_seconds = $AgentsJobMaxRuntimeSeconds

[model_providers."$provider"]
name = "$provider"
base_url = "$url"
wire_api = "responses"
env_key = "$envKey"
request_max_retries = $RequestMaxRetries
stream_max_retries = $StreamMaxRetries
stream_idle_timeout_ms = $StreamIdleTimeoutMs
"@
    }
    if ($preserveTail) { $config = $config.TrimEnd() + "`n`n" + $preserveTail + "`n" }
    Invoke-Run "write $ConfigFile" { [System.IO.File]::WriteAllText($ConfigFile, $config, [System.Text.UTF8Encoding]::new($false)) }
    Write-Ok "Config file ready: $ConfigFile"
}

function Install-RulesAndAgents {
    param([string]$SourceDir)
    $rulesSrc = Join-Path $SourceDir "templates\default.rules"
    $agentsSrc = Join-Path $SourceDir "templates\AGENTS.md"
    $rulesDir = Join-Path $CodexHome "rules"
    $rulesDest = Join-Path $rulesDir "default.rules"

    if (Test-Path $rulesSrc) {
        Invoke-Run "create $rulesDir" { New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null }
        Backup-File $rulesDest
        Invoke-Run "copy $rulesSrc to $rulesDest" { Copy-Item -Path $rulesSrc -Destination $rulesDest -Force }
        Write-Ok "Default rules installed"
    }

    if (Test-Path $agentsSrc) {
        $agentsDest = Join-Path $ProjectDir "AGENTS.md"
        if ((Test-Path $agentsDest) -and (-not $Force)) {
            Write-Warn "AGENTS.md already exists; keeping it. Use -Force to overwrite."
        } else {
            Invoke-Run "create $ProjectDir" { New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null }
            Backup-File $agentsDest
            Invoke-Run "copy $agentsSrc to $agentsDest" { Copy-Item -Path $agentsSrc -Destination $agentsDest -Force }
            Write-Ok "Project AGENTS.md installed"
        }
    }
}

function Update-PowerShellProfile {
    if ($SkipProfileUpdate) { return }
    $sourceLine = ". `"$PrivateEnvFile`""
    Invoke-Run "create PowerShell profile directory" { New-Item -ItemType Directory -Path (Split-Path $PROFILE) -Force | Out-Null }
    if ((Test-Path $PROFILE) -and ((Get-Content $PROFILE -Raw) -like "*$sourceLine*")) {
        Write-Ok "PowerShell profile already loads private env"
        return
    }
    Invoke-Run "append private env loader to PowerShell profile" { Add-Content -Path $PROFILE -Value "`n# Codex Bootstrap secrets`n$sourceLine" }
    Write-Ok "PowerShell profile configured: $PROFILE"
}

function Invoke-CodexSmokeTest {
    if (-not $RunSmokeTest) {
        Write-Info "Skipping Codex reply smoke test"
        return
    }

    Write-Step "8/8" "Verify Codex can reply"
    if ($DryRun) {
        Write-Host "DRY-RUN: source $PrivateEnvFile and run codex exec --ephemeral --ignore-rules $SmokeTestPrompt"
        return
    }
    if (-not (Test-CommandExists "codex")) {
        Fail "Codex CLI not found; cannot run smoke test"
    }
    if (-not (Test-Path $PrivateEnvFile)) {
        Fail "Private env file not found; cannot run smoke test: $PrivateEnvFile"
    }

    # private.env is an installer-managed PowerShell env file. Codex does not auto-source it.
    . "$PrivateEnvFile"

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-smoke-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $replyFile = Join-Path $tmp "codex-reply.txt"
    $logFile = Join-Path $tmp "codex-exec.log"
    $codexPath = (Get-Command codex).Source

    $process = New-Object System.Diagnostics.Process
    $codexArgs = @("exec", "--skip-git-repo-check", "--ephemeral", "--ignore-rules", "--output-last-message", $replyFile, $SmokeTestPrompt)
    if ($codexPath -match '\.(cmd|bat)$') {
        $process.StartInfo.FileName = $env:ComSpec
        [void]$process.StartInfo.ArgumentList.Add("/c")
        [void]$process.StartInfo.ArgumentList.Add($codexPath)
    } else {
        $process.StartInfo.FileName = $codexPath
    }
    foreach ($arg in $codexArgs) {
        [void]$process.StartInfo.ArgumentList.Add($arg)
    }
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.UseShellExecute = $false

    $start = Get-Date
    [void]$process.Start()
    if (-not $process.WaitForExit($SmokeTestTimeoutSeconds * 1000)) {
        try { $process.Kill($true) } catch {}
        Write-Warn "Smoke test timed out after ${SmokeTestTimeoutSeconds}s; log: $logFile"
        Fail "Codex did not reply before timeout"
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    [System.IO.File]::WriteAllText($logFile, "STDOUT:`n$stdout`nSTDERR:`n$stderr", [System.Text.UTF8Encoding]::new($false))
    $elapsed = [Math]::Max(0, [int]((Get-Date) - $start).TotalSeconds)

    if ($process.ExitCode -ne 0) {
        Write-Warn "Smoke test failed with exit code $($process.ExitCode); log: $logFile"
        Fail "Codex reply test failed"
    }
    if (-not (Test-Path $replyFile) -or ((Get-Item $replyFile).Length -eq 0)) {
        Write-Warn "Smoke test produced no final reply; log: $logFile"
        Fail "Codex reply test returned an empty response"
    }

    $preview = ((Get-Content $replyFile -Raw) -replace '\s+', ' ').Trim()
    if ($preview.Length -gt 160) { $preview = $preview.Substring(0, 160) }
    Write-Ok "Codex replied in ${elapsed}s"
    Write-Info "Reply preview: $preview"
}

function Main {
    if ($Help) { Show-Help; return }
    Write-Banner
    if ($Restore) {
        Restore-InstallBackup $Restore
        return
    }
    Assert-EnvKey
    Assert-RequiredInputs

    Write-Step "1/8" "Inspect system and bootstrap settings"
    Write-Info "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Info "Provider: $ProviderId"
    if ($env:CODEX_PROVIDER_ID -and $env:CODEX_PROVIDER_ID -ne $ProviderId) {
        Write-Warn "Ignoring CODEX_PROVIDER_ID; stable Codex provider is fixed to $ProviderId"
    }
    Write-Info "Provider env key: $ProviderEnvKey"
    Write-Info "Model: $Model"
    Write-Info "Reasoning effort: $ReasoningEffort"
    Write-Info "Model verbosity: $ModelVerbosity"
    Write-Info "Reasoning summary: $ReasoningSummary"
    Write-Info "Web search: $WebSearch"
    Write-Info "Subagents: max_threads=$AgentsMaxThreads max_depth=$AgentsMaxDepth job_timeout_s=$AgentsJobMaxRuntimeSeconds"
    Write-Info "Security profile: $SecurityProfile"
    Write-Info "Install backup: $(-not $NoInstallBackup)"
    Write-Info "Smoke test: $RunSmokeTest"
    Write-Info "npm fallback registry: $NpmRegistry"
    Write-Info "Base URL: $BaseUrl"
    if ($Token) { Write-Info "API key: $(Mask-Secret $Token)" }

    Write-Step "2/8" "Load profile and template assets"
    $sourceDir = Get-SourceDir
    Load-Profile $sourceDir
    New-InstallBackup

    Write-Step "3/8" "Install or verify Codex CLI"
    Install-Codex

    Write-Step "4/8" "Write private API key"
    Write-PrivateEnv

    Write-Step "5/8" "Write Codex custom provider config"
    Write-CodexConfig

    Write-Step "6/8" "Install rules and project instructions"
    Install-RulesAndAgents $sourceDir

    Write-Step "7/8" "Ensure PowerShell loads private env"
    Update-PowerShellProfile
    Invoke-CodexSmokeTest

    Write-Ok "Codex bootstrap completed"
    Write-Info "Restart PowerShell or run: . `"$PrivateEnvFile`""
    Write-Info "Try: codex --search"
}

Main
