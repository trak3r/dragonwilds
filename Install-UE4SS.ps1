# Installs a UE4SS build into the Dragonwilds Win64 folder.
# Prefer the Nexus "UE4SS for RSDragonwilds" package when you have it:
#   https://www.nexusmods.com/runescapedragonwilds/mods/4
# This script can fall back to the GitHub experimental zip (worked on 1.0 Steam in our tests).

param(
    [string]$ZipPath,
    [string]$GamePath
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

if (-not $GamePath) {
    $envFile = Join-Path $repoRoot "Environment.ps1"
    if (Test-Path $envFile) { . $envFile; $GamePath = $DRAGONWILDS_INSTALL }
}
if (-not $GamePath) {
    $GamePath = "C:\Program Files (x86)\Steam\steamapps\common\RSDragonwilds\RSDragonwilds"
}

$win64 = Join-Path $GamePath "Binaries\Win64"
if (-not (Test-Path (Join-Path $win64 "RSDragonwilds-Win64-Shipping.exe"))) {
    Write-Error "Game exe not found under $win64"
    exit 1
}

if (-not $ZipPath) {
    Write-Host "No -ZipPath given."
    Write-Host "1) Download UE4SS for RSDragonwilds from Nexus mod 4 (Steam latest)."
    Write-Host "2) Re-run: .\Install-UE4SS.ps1 -ZipPath path\to\UE4SS.zip"
    Write-Host "Or extract the zip so dwmapi.dll + ue4ss\ land in:"
    Write-Host "  $win64"
    exit 2
}

$tmp = Join-Path $env:TEMP ("ue4ss-install-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Expand-Archive -Path $ZipPath -DestinationPath $tmp -Force

# Zip layouts vary: files may be at root or under a single folder.
$dll = Get-ChildItem $tmp -Recurse -Filter "dwmapi.dll" | Select-Object -First 1
$ue4ssDir = Get-ChildItem $tmp -Recurse -Directory -Filter "ue4ss" | Select-Object -First 1
if (-not $dll -or -not $ue4ssDir) {
    Write-Error "Zip does not look like a UE4SS package (need dwmapi.dll and ue4ss\)."
    exit 1
}

Copy-Item $dll.FullName (Join-Path $win64 "dwmapi.dll") -Force
$destUe = Join-Path $win64 "ue4ss"
if (Test-Path $destUe) { Remove-Item $destUe -Recurse -Force }
Copy-Item $ue4ssDir.FullName $destUe -Recurse -Force
Remove-Item $tmp -Recurse -Force

Write-Host "UE4SS installed to $win64"
Write-Host "Next: .\Deploy-Mods.ps1"
