<#
.SYNOPSIS
    Signs this extension via Mozilla AMO (self-distribution / unlisted) and
    drops the signed .xpi into dist/, ready to install permanently on Firefox.

.DESCRIPTION
    Wraps `web-ext sign`. Credentials are read from environment variables so
    they never end up in the script, your shell history, or git:

        $env:WEB_EXT_API_KEY     -> AMO JWT issuer   (looks like user:12345:67)
        $env:WEB_EXT_API_SECRET  -> AMO JWT secret

    Generate both at https://addons.mozilla.org/developers/addon/api/key/
    (requires a free Mozilla add-on developer account).

    "unlisted" means the add-on is signed for private distribution and does
    NOT appear in the public add-ons store.

.EXAMPLE
    $env:WEB_EXT_API_KEY = "user:12345:67"
    $env:WEB_EXT_API_SECRET = "your-secret-here"
    ./sign.ps1

.NOTES
    Bump "version" in src/manifest.json before re-signing an updated build,
    otherwise AMO rejects the upload as a duplicate version.
#>

[CmdletBinding()]
param(
    [string]$SourceDir = "src",
    [string]$ArtifactsDir = "dist",
    [ValidateSet("unlisted", "listed")]
    [string]$Channel = "unlisted"
)

$ErrorActionPreference = "Stop"

# Run from the repo root (the folder this script lives in), whatever the CWD is.
Set-Location -Path $PSScriptRoot

if (-not $env:WEB_EXT_API_KEY -or -not $env:WEB_EXT_API_SECRET) {
    Write-Error @"
Missing AMO credentials.

Set them for the current PowerShell session, then run this script again:

    `$env:WEB_EXT_API_KEY = "user:XXXXX:XX"   # JWT issuer
    `$env:WEB_EXT_API_SECRET = "your-secret"  # JWT secret
    ./sign.ps1

Get the credentials at:
    https://addons.mozilla.org/developers/addon/api/key/
"@
    exit 1
}

$version = (Get-Content -Raw "$SourceDir/manifest.json" | ConvertFrom-Json).version
Write-Host "Signing Twitter Media Assist v$version ($Channel channel)..." -ForegroundColor Cyan

# --no-input keeps it non-interactive; web-ext reads the API key/secret from env.
npx --yes web-ext@latest sign `
    --source-dir $SourceDir `
    --artifacts-dir $ArtifactsDir `
    --channel $Channel `
    --no-input

if ($LASTEXITCODE -ne 0) {
    Write-Error "web-ext sign failed (exit $LASTEXITCODE). See the output above."
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Done. The signed .xpi is in ./$ArtifactsDir" -ForegroundColor Green
Write-Host "Install it: Firefox -> about:addons -> gear -> Install Add-on From File..." -ForegroundColor Green
