# Teflon Ted's Auto Eat

> **One mod, one job** — no kitchen-sink configs or feature creep.

<a href="https://buymeacoffee.com/teflonted"><img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=teflonted&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" width="174" alt="Buy me a coffee" /></a>

## What it does

When **sustenance** or **hydration** drops below **50**, automatically eat or drink one matching item from your inventory.

## Why install it

Keeps your bars topped without digging through the bag mid-adventure.

## How to use it

1. Install [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4).
2. Extract this mod into `RSDragonwilds\Binaries\Win64\ue4ss\Mods\` (so you have `Mods\AutoEat\Scripts\main.lua`).
3. Confirm `mods.txt` has `AutoEat : 1` (or leave `enabled.txt` in the mod folder).
4. Keep food and drink in hotbar or backpack — the mod uses them when a bar dips under 50.

Hardcoded threshold — no config. Respects the game's consume cooldown. Skips combat potions and loot packs. Does not pull from chests.

Pairs fine with **Eat to Heal** (that mod watches HP; this one watches hunger/thirst).

## Requirements

- [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4)
