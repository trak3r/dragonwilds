# Teflon Ted's Spell Cooldown

> **One mod, one job** — no kitchen-sink configs or feature creep.

<a href="https://buymeacoffee.com/teflonted"><img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=teflonted&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" width="174" alt="Buy me a coffee" /></a>

## What it does

Shows a small **toast** near the top of the HUD listing spells that are **currently on cooldown** (name + time left). Rows appear when you cast and disappear when the cooldown ends.

## Why install it

You want a glanceable “what’s still cooling down?” without a full hotkey bar, spell wheel, or config UI. Thin on purpose.

## How to use it

1. Install [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4).
2. Extract this mod into `RSDragonwilds\Binaries\Win64\ue4ss\Mods\` (so you have `Mods\SpellCooldown\Scripts\main.lua`).
3. Confirm `mods.txt` has `SpellCooldown : 1` (or leave `enabled.txt` in the mod folder).
4. Cast a spell — the toast updates while that spell is on cooldown.

No hotkeys. No settings file.

## Requirements

- [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4)

## Notes

- Not a replacement for mods that show cooldowns on a hotbar or spell wheel; this only lists recently-cast / active cooldowns.
- If the toast never appears after casting, check `ue4ss\UE4SS.log` for `[TeflonTed.SpellCooldown]` discovery lines and report them.
