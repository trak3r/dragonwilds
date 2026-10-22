# Teflon Ted's Auto Potion

> **One mod, one job** — no kitchen-sink configs or feature creep.

<a href="https://buymeacoffee.com/teflonted"><img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=teflonted&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" width="174" alt="Buy me a coffee" /></a>

## What it does

When the game applies the **Poison** status, automatically drink one **antipoison** potion from your hotbar or backpack.

Uses the weakest matching pot first (Weak → Lesser → Antipoison Potion) so stronger resistance is saved for swamp travel.

Will **not** drink again while that dose’s resistance perk is still active (poison can rebuild under resist; another flask would be wasted).

## Why install it

Poison ticks hard while you fumble for a flask. This clears it as soon as you’re poisoned — if you have a pot.

## How to use it

1. Install [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4).
2. Extract this mod into `RSDragonwilds\Binaries\Win64\ue4ss\Mods\` (so you have `Mods\AutoPotion\Scripts\main.lua`).
3. Confirm `mods.txt` has `AutoPotion : 1` (or leave `enabled.txt` in the mod folder).
4. Carry Weak / Lesser / Antipoison Potion. Get poisoned — one pot is drunk.

No config. Respects the game’s ~2 s consume cooldown. Does **not** auto-drink combat/heal potions or weapon poison.

## Requirements

- [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4)
