# Teflon Ted's Auto Eat

When **sustenance** or **hydration** drops below **50**, automatically consume one food or drink from your inventory.

- Hardcoded 50% threshold — no config
- Prefers hotbar, then backpack
- Respects the game's ~2 s use delay (won't spam)
- Skips potions and openable loot packs
- Does not touch chests
- Polls every 3s (lightweight; avoids hitching)

Requires [UE4SS for RSDragonwilds](https://www.nexusmods.com/runescapedragonwilds/mods/4).

Check `ue4ss\UE4SS.log` for `[TeflonTed.AutoEat]` lines after loading a world — you should see `SustenanceComponent` / `HydrationComponent` values.
