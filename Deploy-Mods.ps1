# Deploys Teflon Ted Dragonwilds mods into the game's UE4SS Mods folder.
param(
    [string]$GamePath,
    [switch]$Junction
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

function Get-InstallPath {
    if ($GamePath) { return $GamePath }
    $envFile = Join-Path $repoRoot "Environment.ps1"
    if (Test-Path $envFile) {
        . $envFile
        if ($DRAGONWILDS_INSTALL) { return $DRAGONWILDS_INSTALL }
    }
    $default = "C:\Program Files (x86)\Steam\steamapps\common\RSDragonwilds\RSDragonwilds"
    if (Test-Path (Join-Path $default "Binaries\Win64")) { return $default }
    return $null
}

$install = Get-InstallPath
if (-not $install) {
    Write-Error "Could not find Dragonwilds. Copy Environment.ps1.example to Environment.ps1 and set DRAGONWILDS_INSTALL."
    exit 1
}

$ue4ss = Join-Path $install "Binaries\Win64\ue4ss"
$modsDir = Join-Path $ue4ss "Mods"
if (-not (Test-Path $ue4ss)) {
    Write-Error "UE4SS not found at '$ue4ss'. Install UE4SS for RSDragonwilds (Nexus mod 4) first."
    exit 1
}

New-Item -ItemType Directory -Force -Path $modsDir | Out-Null
$modsFile = Join-Path $modsDir "mods.txt"
if (-not (Test-Path $modsFile)) {
    Set-Content -Path $modsFile -Value ""
}

# UnInteract is under development / do not use — never deploy it.
$modNames = @("SortIntoChests", "AutoEat", "EatToHeal", "QuickLaunch", "AutoPotion", "GodMode")
# SpellCooldown abandoned (cooldown read/HUD never got reliable). UnInteract soft-locks input.
$disabledMods = @("UnInteract", "SpellCooldown")
$commonSrc = Join-Path $repoRoot "common"

foreach ($name in $disabledMods) {
    $dest = Join-Path $modsDir $name
    if (Test-Path $dest) {
        Remove-Item $dest -Force -Recurse
        Write-Host "Removed disabled mod from game: $name"
    }
    if (Test-Path $modsFile) {
        $lines = Get-Content $modsFile -ErrorAction SilentlyContinue
        if ($lines) {
            $kept = $lines | Where-Object { $_ -notmatch ("^\s*" + [regex]::Escape($name) + "\s*:") }
            if ($kept.Count -ne @($lines).Count) {
                Set-Content -Path $modsFile -Value $kept
                Write-Host "Disabled in mods.txt: $name"
            }
        }
    }
}

foreach ($name in $modNames) {
    $src = Join-Path $repoRoot "mods\$name"
    if (-not (Test-Path $src)) {
        Write-Warning "Missing mod folder: $src"
        continue
    }
    $dest = Join-Path $modsDir $name
    if (Test-Path $dest) {
        Remove-Item $dest -Force -Recurse
    }
    if ($Junction) {
        $null = cmd /c mklink /J "$dest" "$src"
        Write-Host "Junction: $dest -> $src"
    } else {
        Copy-Item -Path $src -Destination $dest -Recurse -Force
        # Bundle shared Lua helpers beside each mod's Scripts for require()-friendly paths.
        $commonDest = Join-Path $dest "Scripts\teflonted"
        New-Item -ItemType Directory -Force -Path $commonDest | Out-Null
        Copy-Item -Path (Join-Path $commonSrc "*.lua") -Destination $commonDest -Force
        Write-Host "Copied: $name"
    }

    $entry = "$name : 1"
    $content = Get-Content $modsFile -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { $content = "" }
    if ($content -notmatch [regex]::Escape($name)) {
        if ($content -and -not $content.EndsWith("`n")) {
            Add-Content -Path $modsFile -Value ""
        }
        Add-Content -Path $modsFile -Value $entry
        Write-Host "Enabled in mods.txt: $entry"
    }
}

Write-Host "Deploy complete -> $modsDir"
Write-Host "Launch the game and check ue4ss\UE4SS.log for [TeflonTed.*] loaded lines."
