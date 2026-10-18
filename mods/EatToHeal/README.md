# Teflon Ted's Eat to Heal

> **One mod, one job** — no kitchen-sink configs or feature creep.

<a href="https://buymeacoffee.com/teflonted"><img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=teflonted&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" width="174" alt="Buy me a coffee" /></a>

After the health rework, **food heals HP** (healing potions are gone). When your health drops below **20% of max** (or **40 HP** if max can't be read), automatically eat one food from hotbar/backpack.

- Hardcoded threshold — no config
- Scales with Constitution / max HP via `MaxHealthAttribute`
- Respects the game's ~2 s consume cooldown (won't spam / Over Eat)
- Skips drinks, potions, and loot packs (same food classifier as Auto Eat)
- Does not touch chests
- Separate from [Auto Eat](../AutoEat) (hunger/thirst); both can coexist

Requires [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4).
