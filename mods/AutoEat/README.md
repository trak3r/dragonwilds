# Teflon Ted's Auto Eat

> **One mod, one job** — no kitchen-sink configs or feature creep.

<a href="https://buymeacoffee.com/teflonted"><img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=teflonted&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" width="174" alt="Buy me a coffee" /></a>

When **sustenance** or **hydration** drops below **50**, automatically consume one food or drink from your inventory.

- Hardcoded 50% threshold — no config
- Prefers hotbar, then backpack
- Respects the game's ~2 s use delay (won't spam)
- Skips potions and openable loot packs
- Does not touch chests
- Polls every 3s (lightweight; avoids hitching)

Requires [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4).

Check `ue4ss\UE4SS.log` for `[TeflonTed.AutoEat]` lines after loading a world — you should see `SustenanceComponent` / `HydrationComponent` values.
