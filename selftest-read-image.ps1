param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath
)

$ErrorActionPreference = 'Stop'
$Proxy = Join-Path $PSScriptRoot 'dist\win-x64\PowerShell.MCP.Proxy.exe'
if (-not (Test-Path -LiteralPath $Proxy -PathType Leaf)) { throw "Proxy not found: $Proxy" }
if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) { throw "Image not found: $ImagePath" }

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $Proxy
$psi.WorkingDirectory = $PSScriptRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$p = [System.Diagnostics.Process]::new()
$p.StartInfo = $psi
[void]$p.Start()

function Read-McpLine([int]$TimeoutMs = 8000) {
    $task = $p.StandardOutput.ReadLineAsync()
    if (-not $task.Wait($TimeoutMs)) { throw 'Timed out waiting for MCP stdout.' }
    return $task.Result
}

try {
    $init = @{
        jsonrpc = '2.0'; id = 1; method = 'initialize'
        params = @{
            protocolVersion = '2025-06-18'
            capabilities = @{}
            clientInfo = @{ name = 'pwm-vision-selftest'; version = '1.0' }
        }
    } | ConvertTo-Json -Compress -Depth 8
    $p.StandardInput.WriteLine($init)
    $p.StandardInput.Flush()
    $initResponse = Read-McpLine | ConvertFrom-Json -Depth 20

    $p.StandardInput.WriteLine((@{ jsonrpc='2.0'; method='notifications/initialized'; params=@{} } | ConvertTo-Json -Compress -Depth 4))
    $p.StandardInput.Flush()

    $p.StandardInput.WriteLine((@{ jsonrpc='2.0'; id=2; method='tools/list'; params=@{} } | ConvertTo-Json -Compress -Depth 5))
    $p.StandardInput.Flush()
    $tools = Read-McpLine | ConvertFrom-Json -Depth 20
    $names = @($tools.result.tools | ForEach-Object name)
    if ($names -notcontains 'read_image') { throw 'read_image is not advertised by tools/list.' }

    $p.StandardInput.WriteLine((@{ jsonrpc='2.0'; id=3; method='tools/call'; params=@{ name='read_image'; arguments=@{ path=(Resolve-Path -LiteralPath $ImagePath).Path } } } | ConvertTo-Json -Compress -Depth 8))
    $p.StandardInput.Flush()
    $call = Read-McpLine | ConvertFrom-Json -Depth 20
    $content = @($call.result.content)
    if ($content.Count -ne 1) { throw "Expected one content block; got $($content.Count)." }
    $image = $content[0]
    if ($image.type -ne 'image') { throw "Expected native MCP image block; got type '$($image.type)'." }

    $wireBytes = [Convert]::FromBase64String([string]$image.data)
    $sourceBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ImagePath).Path)
    $wireHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($wireBytes))
    $sourceHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($sourceBytes))
    if ($wireHash -ne $sourceHash) { throw 'Image bytes changed during MCP serialization.' }

    Write-Host 'PASS: native MCP image output verified.' -ForegroundColor Green
    Write-Host "Server     : $($initResponse.result.serverInfo.name) $($initResponse.result.serverInfo.version)"
    Write-Host "Content    : type=$($image.type), mimeType=$($image.mimeType)"
    Write-Host "Image bytes: $($wireBytes.Length)"
    Write-Host "SHA256     : $wireHash"
}
finally {
    try { $p.StandardInput.Close() } catch {}
    if (-not $p.HasExited) { $p.Kill($true) }
    $p.Dispose()
}
