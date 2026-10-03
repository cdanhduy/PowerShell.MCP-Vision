# ============================================================
# OpenAI Secure MCP Tunnel -> PowerShell.MCP (stdio)
# ============================================================

# -----------------------------
# CONFIG
# -----------------------------

$TunnelClient = "C:\Program Files (x86)\tunnel-client-v0.0.14-windows-amd64\tunnel-client.exe"
$McpProxy     = Join-Path $PSScriptRoot "dist\win-x64\PowerShell.MCP.Proxy.exe"

$McpCommand   = "'" + $McpProxy + "'"

$Profile      = "powershell-mcp-vision"
$ProfileDir   = Join-Path $env:APPDATA "tunnel-client"

$TunnelId     = "tunnel_REPLACE_ME"

# EDIT THIS
$ControlPlaneApiKey = "PASTE_API_KEY_HERE"

$HealthListen = "127.0.0.1:8081"

# -----------------------------
# NO NEED TO EDIT BELOW
# -----------------------------

$ErrorActionPreference = "Stop"

function Fail([string]$Message, [int]$Code = 1) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host ""
    exit $Code
}

Write-Host ""
Write-Host "=== OpenAI Secure MCP Tunnel - MCP PWM Vision ===" -ForegroundColor Cyan
Write-Host "Profile : $Profile"
Write-Host "Tunnel  : $TunnelId"
Write-Host "MCP     : $McpProxy"
Write-Host ""

# ------------------------------------------------------------
# Validate
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $TunnelClient -PathType Leaf)) {
    Fail "tunnel-client.exe not found: $TunnelClient"
}

if (-not (Test-Path -LiteralPath $McpProxy -PathType Leaf)) {
    Fail "PowerShell.MCP.Proxy.exe not found: $McpProxy"
}

if ($TunnelId -notmatch '^tunnel_[A-Za-z0-9]+$') {
    Fail "Invalid tunnel ID: $TunnelId"
}

if (
    [string]::IsNullOrWhiteSpace($ControlPlaneApiKey) -or
    $ControlPlaneApiKey -eq "PASTE_API_KEY_HERE"
) {
    Fail "Set `$ControlPlaneApiKey in CONFIG."
}

# ------------------------------------------------------------
# Clean authentication/config environment
# ------------------------------------------------------------

$ControlPlaneApiKey = $ControlPlaneApiKey.Trim()

Remove-Item Env:OPENAI_ADMIN_KEY              -ErrorAction SilentlyContinue
Remove-Item Env:OPENAI_API_KEY                -ErrorAction SilentlyContinue
Remove-Item Env:CONTROL_PLANE_TUNNEL_ID       -ErrorAction SilentlyContinue
Remove-Item Env:CONTROL_PLANE_BASE_URL        -ErrorAction SilentlyContinue
Remove-Item Env:CONTROL_PLANE_URL_PATH        -ErrorAction SilentlyContinue
Remove-Item Env:CONTROL_PLANE_ORGANIZATION_ID -ErrorAction SilentlyContinue
Remove-Item Env:TUNNEL_CLIENT_CONFIG          -ErrorAction SilentlyContinue
Remove-Item Env:TUNNEL_CLIENT_PROFILE         -ErrorAction SilentlyContinue
Remove-Item Env:TUNNEL_CLIENT_PROFILE_FILE    -ErrorAction SilentlyContinue
Remove-Item Env:TUNNEL_CLIENT_PROFILE_DIR     -ErrorAction SilentlyContinue

$env:CONTROL_PLANE_API_KEY = $ControlPlaneApiKey

Write-Host "[1/3] Runtime authentication configured." -ForegroundColor Green

# ------------------------------------------------------------
# Health/admin port
# ------------------------------------------------------------

$PortOwner = Get-NetTCPConnection `
    -LocalPort 8081 `
    -State Listen `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($PortOwner) {
    Write-Host "[2/3] Port 8081 occupied; using automatic health port." -ForegroundColor Yellow
    $HealthListen = "127.0.0.1:0"
}
else {
    Write-Host "[2/3] Health listener: $HealthListen" -ForegroundColor Green
}

# ------------------------------------------------------------
# Materialize/update profile
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

& $TunnelClient init `
    --sample sample_mcp_stdio_local `
    --profile $Profile `
    --profile-dir $ProfileDir `
    --tunnel-id $TunnelId `
    --control-plane-api-key-ref "env:CONTROL_PLANE_API_KEY" `
    --mcp-command $McpCommand `
    --health-listen-addr $HealthListen `
    --force

if ($LASTEXITCODE -ne 0) {
    Fail "tunnel-client init failed." $LASTEXITCODE
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3/3] Starting tunnel..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop."
Write-Host ""

& $TunnelClient run `
    --profile $Profile `
    --profile-dir $ProfileDir `
    --control-plane.api-key "env:CONTROL_PLANE_API_KEY" `
    --control-plane.tunnel-id $TunnelId `
    --health.listen-addr $HealthListen

$ExitCode = $LASTEXITCODE

if ($ExitCode -ne 0) {
    Fail "tunnel-client exited with code $ExitCode." $ExitCode
}