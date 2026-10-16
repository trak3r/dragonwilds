-- Teflon Ted's Sort Into Chests — RuneScape: Dragonwilds (UE4SS)
-- Hotkey ` deposits backpack stacks into nearby chests that already hold that item.

local TAG = "[TeflonTed.SortIntoChests] "
local VERSION = "1.0.0"

local function setupPath()
    local src = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
    local dir = src:match("^(.*)[/\\]")
    if dir then
        -- Deploy copies common/*.lua into Scripts/teflonted/ (require "teflonted.util")
        package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path
    end
end
setupPath()

local U = require("teflonted.util")
local Inv = require("teflonted.inventory")
local Storage = require("teflonted.storage")

local function log(msg)
    print(TAG .. tostring(msg) .. "\n")
end

local pending = false

local function sortNow()
    local pc = U.localPC()
    if not pc then
        log("no local player")
        return
    end
    if U.uiBlocking(pc) then
        log("ignored: UI/cursor active")
        return
    end
    local pawn = U.playerPawn(pc)
    if not pawn then
        log("no player character")
        return
    end
    if not U.isHost(pc) then
        -- MoveItem is host/solo-authoritative on this game; refuse quietly for guests.
        log("ignored: not host/solo (item moves need authority)")
        return
    end
    local bag = U.playerBag(pc)
    if not bag then
        log("no backpack")
        return
    end
    local chests = Storage.findNearbyChests(pawn, Storage.RADIUS_M)
    if #chests == 0 then
        log("no nearby chests")
        return
    end
    local moved = Storage.sortIntoChests(pc, pawn, bag, chests)
    if moved > 0 then
        log(string.format("Sorted %d item(s) into chests (%d chests in range)", moved, #chests))
    else
        log(string.format("Nothing to sort (%d chests in range)", #chests))
    end
end

local function onHotkey()
    pending = true
end

-- OEM_THREE is the `~ key on US keyboards (VK_OEM_3).
-- Bare tilde is claimed by ConsoleEnablerMod, so bind ALT+` (Valheim-adjacent, no console fight).
local key = (Key and (Key.OEM_THREE or Key.TILDE or Key.OEM_8)) or nil
local alt = ModifierKey and ModifierKey.ALT
if key and alt then
    local ok = pcall(RegisterKeyBind, key, { alt }, function()
        pcall(ExecuteInGameThread, onHotkey)
    end)
    if ok then
        log("bound sort hotkey to ALT+` (OEM_THREE)")
    else
        log("could not bind ALT+` hotkey")
    end
elseif key then
    local ok = pcall(RegisterKeyBind, key, function()
        pcall(ExecuteInGameThread, onHotkey)
    end)
    if ok then log("bound sort hotkey to OEM_THREE (no ModifierKey.ALT)") else log("could not bind hotkey") end
else
    log("Key.OEM_THREE unavailable; sort hotkey not bound")
end

local function tick()
    if not pending then return end
    pending = false
    local ok, err = pcall(sortNow)
    if not ok then log("sort error: " .. tostring(err)) end
end

local okLoop = pcall(LoopInGameThreadWithDelay, 100, function()
    pcall(tick)
end)
if not okLoop then
    local queued = false
    LoopAsync(100, function()
        if queued then return false end
        queued = true
        local sent = pcall(ExecuteInGameThread, function()
            queued = false
            pcall(tick)
        end)
        if not sent then queued = false end
        return false
    end)
end

log("loaded v" .. VERSION .. " — press ALT+` to sort into nearby chests")
