[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'bin\cli-proxy-api.exe'
$config = Join-Path $root 'config.yaml'

if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw 'Proxy binary missing. Run scripts\Install-Proxy.ps1 first.'
}
if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
    throw 'config.yaml missing. Copy config.example.yaml and set a proxy key first.'
}

Write-Host 'Starting the Claude OAuth flow. A browser window will open.'
Write-Host 'Verify the sign-in page is on the official Anthropic domain before approving.'
Write-Host 'Do not share the terminal output; it contains authorization details.'

Push-Location $root
try {
    & $exe -config $config -claude-login
    if ($LASTEXITCODE -ne 0) { throw "claude-login exited with code $LASTEXITCODE." }
} finally {
    Pop-Location
}
