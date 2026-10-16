# Teflon Ted's Dragonwilds Mod Suite

> **One mod, one job** — no kitchen-sink configs or feature creep.

Single-purpose [UE4SS](https://www.nexusmods.com/runescapedragonwilds/mods/4) Lua QoL mods for *RuneScape: Dragonwilds*. Same doctrine as the Valheim suite; different engine (Unreal, not Unity).

## Mods

| Mod | One-liner | Trigger |
|-----|-----------|---------|
| [Sort Into Chests](mods/SortIntoChests) | **Alt+`** quick-stacks into chests that already hold that item | ~20 m; skips hotbar |
| [Auto Eat](mods/AutoEat) | Eat/drink from inventory when bars drop below 50 | Sustenance / Hydration |

Shared helpers live in [`common/`](common) and are copied into each mod on deploy.

## Requirements

| Need | Notes |
|------|--------|
| RuneScape: Dragonwilds (Steam) | Tested path: `...\steamapps\common\RSDragonwilds\RSDragonwilds` |
| [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4) | Extract so `dwmapi.dll` + `ue4ss\` sit next to `RSDragonwilds-Win64-Shipping.exe` |

A GitHub experimental UE4SS build may work for development; prefer the Nexus Dragonwilds package if mods fail to start.

## Setup

1. Install UE4SS into `Binaries\Win64\` (Nexus [mod 4](https://www.nexusmods.com/runescapedragonwilds/mods/4), or `.\Install-UE4SS.ps1 -ZipPath ...`).
2. Copy `Environment.ps1.example` → `Environment.ps1` (already set for the default Steam path).
3. Deploy:

```powershell
.\Deploy-Mods.ps1
```

Or double-click `Launch-Dragonwilds.bat` (deploys, then starts the game).

4. Confirm in `Binaries\Win64\ue4ss\UE4SS.log`:

```
[TeflonTed.SortIntoChests] loaded ...
[TeflonTed.AutoEat] loaded ...
```

## Modding notes

- Jagex [encourages QoL mods](https://legal.jagex.com/docs/policies/runescape-dragonwilds-community-modding-guidelines) for single-player; don't use unfair advantages in shared/multiplayer worlds.
- No Easy Anti-Cheat / BattlEye on this install. Steam **Verify integrity** can remove UE4SS files — reinstall the loader if that happens.
- Sort moves use host authority (`MoveItem`). AutoEat uses `InventoryController:UseItemFromInventory` (works for packs from Open All; food/drink verified the same route).

## Layout

```
dragonwilds/
  common/                 shared Lua
  mods/SortIntoChests/
  mods/AutoEat/
  Deploy-Mods.ps1
  Launch-Dragonwilds.bat
  Environment.ps1.example
```
