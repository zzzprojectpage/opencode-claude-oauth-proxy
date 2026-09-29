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

Write-Host 'Starting CLIProxyAPI on 127.0.0.1:8317. Press Ctrl+C to stop.'
Write-Host 'Do not pass -local-model: the remote model catalog refresh is what makes'
Write-Host 'newly released model IDs (e.g. claude-sonnet-5-5) appear automatically.'

Push-Location $root
try {
    # Intentionally no -local-model so the public catalog refresh stays enabled.
    & $exe -config $config
} finally {
    Pop-Location
}
