<#
.SYNOPSIS
    Publishes a GitHub release for the current version, attaching the signed .xpi.

.DESCRIPTION
    Reads the version from src/manifest.json, finds the matching signed package
    in dist/ (produced by ./sign.ps1), copies it to a clean asset name, and
    creates a GitHub release tagged v<version> with that .xpi attached.

    Run ./sign.ps1 first so the signed .xpi exists. Requires the GitHub CLI
    (`gh`) to be installed and authenticated (`gh auth status`).

.PARAMETER Repo
    Target repository. Defaults to faragouji/TwitterMediaAssist.

.PARAMETER Target
    Commit-ish the tag is created from. Defaults to master.

.PARAMETER NotesFile
    Optional path to a file with the release notes (Markdown). If omitted, a
    short default note with install instructions is used.

.EXAMPLE
    ./sign.ps1
    ./release.ps1

.EXAMPLE
    ./release.ps1 -NotesFile .\notes-3.3.6.md
#>

[CmdletBinding()]
param(
    [string]$Repo = "faragouji/TwitterMediaAssist",
    [string]$Target = "master",
    [string]$NotesFile
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

# gh must be present and authenticated.
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) not found. Install it from https://cli.github.com/"
    exit 1
}

$version = (Get-Content -Raw "src/manifest.json" | ConvertFrom-Json).version
$tag = "v$version"
Write-Host "Preparing release $tag for $Repo..." -ForegroundColor Cyan

# Refuse to overwrite an existing release/tag.
gh release view $tag --repo $Repo *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Error "Release $tag already exists on $Repo. Bump the version in src/manifest.json (and re-sign) first."
    exit 1
}

# Find the signed .xpi for this version. sign.ps1 leaves an AMO-named file like
# "<hash>-<version>.xpi" in dist/; pick the newest match.
$signed = Get-ChildItem -Path "dist" -Filter "*-$version.xpi" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $signed) {
    Write-Error "No signed .xpi for version $version found in dist/. Run ./sign.ps1 first."
    exit 1
}

# Copy to a clean, human-friendly asset name for the download.
$assetName = "twitter_media_assist-$version.xpi"
$assetPath = Join-Path "dist" $assetName
if ($signed.FullName -ne (Resolve-Path -LiteralPath $assetPath -ErrorAction SilentlyContinue)) {
    Copy-Item -LiteralPath $signed.FullName -Destination $assetPath -Force
}
Write-Host "Asset: $assetPath" -ForegroundColor DarkGray

# Release notes: use the provided file, or a short default.
$tempNotes = $null
if (-not $NotesFile) {
    $tempNotes = New-TemporaryFile
    @"
Signed build ($tag), for self-distribution (AMO unlisted) — installable
permanently on Firefox release.

## Install
Download ``$assetName`` below, then in Firefox:
``about:addons`` -> gear -> **Install Add-on From File...** -> pick the ``.xpi``.

See the README for the full list of changes in this fork.
"@ | Set-Content -LiteralPath $tempNotes -Encoding utf8
    $NotesFile = $tempNotes
}

try {
    gh release create $tag `
        --repo $Repo `
        --target $Target `
        --title $tag `
        --latest `
        --notes-file $NotesFile `
        "$assetPath#Twitter Media Assist $version (signed .xpi)"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh release create failed (exit $LASTEXITCODE)."
        exit $LASTEXITCODE
    }
}
finally {
    if ($tempNotes) { Remove-Item -LiteralPath $tempNotes -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "Released $tag with $assetName attached." -ForegroundColor Green
