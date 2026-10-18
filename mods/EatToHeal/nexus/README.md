# Teflon Ted's Eat to Heal

> **One mod, one job** — no kitchen-sink configs or feature creep.

<a href="https://buymeacoffee.com/teflonted"><img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=teflonted&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" width="174" alt="Buy me a coffee" /></a>

## What it does

After the health rework, **food heals HP**. When your health drops below **30% of max** (or **50 HP** if max can't be read), automatically eat one food from hotbar/backpack.

## Why install it

Healing potions are gone — this keeps you snacking in a fight so HP doesn't get scary-low before you remember to eat.

## How to use it

1. Install [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4).
2. Extract this mod into `RSDragonwilds\Binaries\Win64\ue4ss\Mods\` (so you have `Mods\EatToHeal\Scripts\main.lua`).
3. Confirm `mods.txt` has `EatToHeal : 1` (or leave `enabled.txt` in the mod folder).
4. Carry food. When HP crosses the threshold, one food is eaten.

Hardcoded threshold — no config. Respects the game's ~2 s consume cooldown. Skips drinks, potions, and loot packs.

Pairs fine with **Auto Eat** (hunger/thirst); both can run together.

## Requirements

- [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4)
