I want to create a suite of single-purpose RuneScape: Dragonwilds mods.

# Design rules

- each mod does one thing only
- minimal tuning options (preferably none)
- Teflon Ted branding (same spirit as the Valheim suite)
- UE4SS + Lua (this game is Unreal, not Unity/BepInEx)

# Mods

- sort into nearby chests. when pressing Alt+` , all non-hotbar backpack items move into nearby chests that already contain the same items
- auto eat (+ drink). when sustenance or hydration drops below 50, consume one matching food or drink from inventory

# Plan

- create each mod in a subfolder under this `dragonwilds` folder
- share helpers under `common/` when both mods need the same inventory/storage code
- deploy with `Deploy-Mods.ps1` into `Binaries\Win64\ue4ss\Mods\`
