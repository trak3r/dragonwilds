#Requires -Version 5.1
<#
.SYNOPSIS
  Build a Nexus-ready ZIP for a Teflon Ted Dragonwilds UE4SS mod.

.DESCRIPTION
  Stages Mods/<Name>/ with Scripts (including bundled common helpers), enabled.txt,
  player README + CHANGELOG from mods/<Name>/nexus/, then zips that folder.

  Upload the ZIP on Nexus as a Main File. Upload nexus/icon.png as the mod image.

.EXAMPLE
  .\Pack-Nexus.ps1 -Mod SortIntoChests
  .\Pack-Nexus.ps1 -Mod AutoEat -Version 1.1.0
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("SortIntoChests", "AutoEat", "EatToHeal", "QuickLaunch")]
    [string] $Mod,

    [string] $Version
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$ModDir = Join-Path $Root "mods\$Mod"
$NexusDir = Join-Path $ModDir "nexus"
$CommonSrc = Join-Path $Root "common"

if (-not (Test-Path $ModDir)) { throw "Mod folder not found: $ModDir" }
if (-not (Test-Path (Join-Path $NexusDir "README.md"))) { throw "Missing $NexusDir\README.md" }
if (-not (Test-Path (Join-Path $NexusDir "icon.png"))) { throw "Missing $NexusDir\icon.png (approve icon first)" }
if (-not (Test-Path (Join-Path $ModDir "Scripts\main.lua"))) { throw "Missing Scripts\main.lua" }

# Version from -Version, else from main.lua VERSION = "x.y.z", else 1.0.0
if (-not $Version) {
    $main = Get-Content (Join-Path $ModDir "Scripts\main.lua") -Raw
    if ($main -match 'VERSION\s*=\s*"([^"]+)"') { $Version = $Matches[1] } else { $Version = "1.0.0" }
}

$dist = Join-Path $Root "dist"
$stageRoot = Join-Path $dist "nexus\$Mod-$Version"
$modStage = Join-Path $stageRoot $Mod
if (Test-Path $stageRoot) { Remove-Item $stageRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $modStage "Scripts\teflonted") | Out-Null

Copy-Item (Join-Path $ModDir "Scripts\main.lua") (Join-Path $modStage "Scripts\main.lua")
Copy-Item (Join-Path $CommonSrc "*.lua") (Join-Path $modStage "Scripts\teflonted") -Force
if (Test-Path (Join-Path $ModDir "enabled.txt")) {
    Copy-Item (Join-Path $ModDir "enabled.txt") $modStage
} else {
    Set-Content -Path (Join-Path $modStage "enabled.txt") -Value ""
}
Copy-Item (Join-Path $NexusDir "README.md") (Join-Path $modStage "README.md")
if (Test-Path (Join-Path $NexusDir "CHANGELOG.md")) {
    Copy-Item (Join-Path $NexusDir "CHANGELOG.md") (Join-Path $modStage "CHANGELOG.md")
}

# Icon for Nexus Images tab (kept beside the zip, not inside Mods/)
$iconOut = Join-Path $dist "TeflonTed-$Mod-$Version-icon.png"
Copy-Item (Join-Path $NexusDir "icon.png") $iconOut -Force

$zipPath = Join-Path $dist "TeflonTed-$Mod-$Version-Nexus.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
# Zip so extracting into ue4ss\Mods\ yields Mods\<Mod>\...
[System.IO.Compression.ZipFile]::CreateFromDirectory($stageRoot, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

Write-Host ""
Write-Host "Package ready: $zipPath"
Write-Host "Nexus image:   $iconOut"
Write-Host "Extract into:  ...\Binaries\Win64\ue4ss\Mods\"
Write-Host "Upload:        https://www.nexusmods.com/runescapedragonwilds/mods/"
