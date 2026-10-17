# Teflon Ted's Un-Interact

> **UNDER DEVELOPMENT — DO NOT USE**
>
> Closing CommonUI panels via UE4SS currently soft-locks input (cursor/shells remain, keyboard dead). Kept in the repo for research only; **not deployed** by `Deploy-Mods.ps1` / `Launch-Dragonwilds.bat`.

<a href="https://buymeacoffee.com/teflonted"><img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=teflonted&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" width="174" alt="Buy me a coffee" /></a>

## Intended job (not shipping)

Press **E** (Interact) again to leave chests, stations, conversations, and other interaction panels — no Escape required.

Vanilla has no setting for this: cancel/close is Esc, and Interact is not rebindable as a close action.

## Status

| Attempt | Result |
|---------|--------|
| Mass `DeactivateWidget` | Soft-lock (HUD + shells) |
| `BP_OnHandleBackAction` | No-op from Lua |
| Score by `GetFullName()` | Nibbled child widgets (`InventoryInputs`, slots) |
| `*MainPanel*` only + restore input | Still soft-locked control |

Blocked on a safe Esc-equivalent that unwinds CommonUI without breaking input. Use **Escape** in-game for now.
