# Publishing to Nexus (RuneScape: Dragonwilds)

Thunderstore has **no** Dragonwilds community. Publish on [Nexus](https://www.nexusmods.com/runescapedragonwilds) under **UE4SS Mods**.

## Shippable mods

| Mod | Folder | Notes |
|-----|--------|--------|
| Sort Into Chests | `mods/SortIntoChests` | Alt+` quick-stack |
| Auto Eat | `mods/AutoEat` | Hunger/thirst &lt; 50 |
| Eat to Heal | `mods/EatToHeal` | HP &lt; 30% / 50 |
| Quick Launch | `mods/QuickLaunch` | Skip menus into last session |

**Do not publish** `UnInteract` (soft-locks input). SpellCooldown was shelved (unreliable CD read/HUD).

## Per-mod Nexus kit

Each shippable mod has `mods/<Name>/nexus/`:

- `README.md` — paste into the Nexus description (also bundled in the ZIP)
- `CHANGELOG.md` — file changelog / description updates
- `icon.png` / `icon-draft.png` — 256×256 suite icon (**review before first commit**)

## Pack a release ZIP

```powershell
.\Pack-Nexus.ps1 -Mod SortIntoChests
.\Pack-Nexus.ps1 -Mod AutoEat
.\Pack-Nexus.ps1 -Mod EatToHeal
.\Pack-Nexus.ps1 -Mod QuickLaunch
```

Outputs under `dist/`:

- `TeflonTed-<Mod>-<ver>-Nexus.zip` — extract into `ue4ss\Mods\`
- `TeflonTed-<Mod>-<ver>-icon.png` — upload as the Nexus mod image

## Nexus listing checklist

1. Category: **UE4SS Mods** (or Misc if that fits the site better)
2. Title: `Teflon Ted's <Mod Name>`
3. Short description: one line from the README “What it does”
4. Description: paste `nexus/README.md` (Nexus supports the coffee badge HTML)
5. Requirements: soft-require [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4)
6. Main file: the `-Nexus.zip`
7. Image: the `-icon.png`
8. Tagline doctrine: **One mod, one job**

## Install blurb (for players)

1. Install UE4SS for RSDragonwilds (Nexus mod 4).
2. Extract the ZIP into `...\RSDragonwilds\Binaries\Win64\ue4ss\Mods\`.
3. Launch; confirm `[TeflonTed.*] loaded` lines in `ue4ss\UE4SS.log`.
