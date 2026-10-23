# Teflon Ted's God Mode (bare bones)

Always-on combat invulnerability while this mod is loaded. **No hotkey. No poll loop.**

Applies once when you enter a world (KithMyTrainer #684 signatures), then does nothing.

## Enable / disable

**Off by default** — `Deploy-Mods.ps1` / the launcher do not install it (listed in `$disabledMods`).

To turn on for a tough fight:
1. Add `"GodMode"` to `$modNames` in `Deploy-Mods.ps1` and remove it from `$disabledMods`.
2. Run `Launch-Dragonwilds.bat` (or `.\Deploy-Mods.ps1`).
3. Confirm `[TeflonTed.GodMode] ON (one-shot)` in `UE4SS.log`.

To turn off again: put `GodMode` back in `$disabledMods` only, redeploy (script removes it from the game Mods folder).

## Credits

- API: KithMyAth [KithMyTrainer](https://www.nexusmods.com/runescapedragonwilds/mods/684)
- Idea: evoe [Godmode Toggle](https://www.nexusmods.com/runescapedragonwilds/mods/34)
