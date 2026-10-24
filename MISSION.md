I want to create a suite of single-purpose RuneScape: Dragonwilds mods.

# Design rules

- each mod does one thing only
- minimal tuning options (preferably none)
- Teflon Ted branding (same spirit as the Valheim suite)
- UE4SS + Lua (this game is Unreal, not Unity/BepInEx)

# Mods

- sort into nearby chests. when pressing Shift+` (~), all non-hotbar backpack items move into nearby chests that already contain the same items
- auto eat (+ drink). when sustenance or hydration drops below 50, consume one matching food or drink from inventory
- un-interact. when an interaction UI is already open, pressing E again dismisses it (vanilla forces Esc) — **shelved / do not use**
- quick launch. on game start, auto-advance into the last character + world (vanilla defaults them but still makes you click through)
- eat to heal. when health drops below ~30% (or ~50 HP), auto-eat food (post-0.12: food heals, potions gone)
- ~~spell cooldown~~ — **abandoned** (magic components found; ActiveCooldowns not readable via UE4SS; HUD never showed live CDs)
- auto potion. when poisoned, drink one antipoison potion from inventory (weakest first)

# Plan

- create each mod in a subfolder under this `dragonwilds` folder
- share helpers under `common/` when both mods need the same inventory/storage code
- deploy with `Deploy-Mods.ps1` into `Binaries\Win64\ue4ss\Mods\`
