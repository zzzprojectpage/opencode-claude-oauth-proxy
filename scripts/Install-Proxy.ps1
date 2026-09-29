[CmdletBinding()]
param([string]$Version = 'latest')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$binDir = Join-Path $root 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

if ($Version -eq 'latest') {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest'
} else {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/tags/$Version"
}
$tag = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -like '*windows_amd64.zip' } | Select-Object -First 1
if (-not $asset) { throw "No windows_amd64 release asset found for $tag." }
$checksums = $release.assets | Where-Object { $_.name -eq 'checksums.txt' } | Select-Object -First 1

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('clipProxy-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp $asset.name
    Write-Host "Downloading $tag ($($asset.name))..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing

    # Prefer the release asset digest when GitHub provides one.
    if ($asset.digest -and $asset.digest -like 'sha256:*') {
        $expected = $asset.digest.Substring(7)
        $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected.ToLowerInvariant()) { throw 'Downloaded archive failed SHA-256 verification.' }
    }

    # Also verify against the published checksums.txt when available.
    if ($checksums) {
        $csFile = Join-Path $tmp 'checksums.txt'
        Invoke-WebRequest -Uri $checksums.browser_download_url -OutFile $csFile -UseBasicParsing
        $match = Select-String -LiteralPath $csFile -Pattern ([regex]::Escape($asset.name)) | Select-Object -First 1
        if ($match) {
            $expected2 = ($match.Line -split '\s+')[0].ToLowerInvariant()
            $actual2 = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual2 -ne $expected2) { throw 'Archive does not match the published checksums.txt.' }
        }
    }

    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
    $exe = Get-ChildItem -LiteralPath $tmp -Recurse -Filter 'cli-proxy-api.exe' | Select-Object -First 1
    if (-not $exe) { throw 'cli-proxy-api.exe was not found in the release archive.' }
    Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $binDir 'cli-proxy-api.exe') -Force
    Write-Host "Installed $tag to $binDir\cli-proxy-api.exe"
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
