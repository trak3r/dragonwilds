# Teflon Ted's God Mode (bare bones)

Always-on combat invulnerability while this mod is loaded. **No hotkey. No poll loop.**

Applies once when you enter a world (KithMyTrainer #684 signatures), then does nothing.

## Test plan (perf)

1. Play without this mod — note FPS feel.
2. `GodMode : 1` in `mods.txt`, restart, load in — compare.
3. Set `GodMode : 0` (or remove folder) to turn off.

## Credits

- API: KithMyAth [KithMyTrainer](https://www.nexusmods.com/runescapedragonwilds/mods/684)
- Idea: evoe [Godmode Toggle](https://www.nexusmods.com/runescapedragonwilds/mods/34)
