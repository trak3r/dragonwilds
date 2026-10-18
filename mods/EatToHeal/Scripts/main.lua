-- Teflon Ted's Eat to Heal — RuneScape: Dragonwilds (UE4SS)
-- After the 0.12 health rework, food heals HP (potions gone). When health is low,
-- auto-eat one food from hotbar/backpack. Respects the game's consume cooldown.

local TAG = "[TeflonTed.EatToHeal] "
local VERSION = "1.0.0"
local HP_FRACTION = 0.20   -- prefer 20% of max (scales with Constitution)
local HP_ABSOLUTE = 40     -- fallback if MaxHealth unread
local POLL_MS = 1000       -- attr reads only; safe to poll faster than AutoEat
local USE_COOLDOWN = 2.25  -- game consume cooldown ~2s

local function setupPath()
    local src = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
    local dir = src:match("^(.*)[/\\]")
    if dir then
        package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path
    end
end
setupPath()

local U = require("teflonted.util")
local Inv = require("teflonted.inventory")
local Food = require("teflonted.consumable")

local function log(msg)
    print(TAG .. tostring(msg) .. "\n")
end

local S = {
    nextUseAt = 0,
    readyAt = nil,
    world = nil,
    loggedSlots = false,
}

local function findFoodSlot(bag)
    local last = math.min(Inv.BAG_MAIN_LAST, Inv.slotCount(bag) - 1)
    for i = 0, last do
        local ok, d, n = Inv.readSlot(bag, i)
        if ok and d and n and n > 0 and Food.isKind(d, "food") then
            return i, d
        end
    end
    return nil, nil
end

local function logHotbarOnce(bag)
    if S.loggedSlots then return end
    S.loggedSlots = true
    local last = math.min(Inv.BAG_MAIN_LAST, Inv.slotCount(bag) - 1)
    for i = 0, last do
        local ok, d, n = Inv.readSlot(bag, i)
        if ok and d and n and n > 0 then
            log(string.format("inv[%d] x%d %s", i, n, Food.describe(d)))
        end
    end
end

local function healthSnapshot(pawn)
    local hp = U.readAttr(pawn, "HealthAttribute")
    if hp == nil then
        hp = U.readNumber(pawn, { "GetHealth", "CurrentHealth", "Health" })
    end
    local max = U.readAttr(pawn, "MaxHealthAttribute")
    if max == nil then
        max = U.readNumber(pawn, { "GetMaxHealth", "MaxHealth", "MaxHealthValue" })
    end
    return hp, max
end

-- True when HP is critically low. Prefer % of max; fall back to absolute points.
local function needsHeal(hp, max)
    if type(hp) ~= "number" or hp <= 0 then return false end
    if type(max) == "number" and max > 0 then
        return (hp / max) < HP_FRACTION
    end
    return hp < HP_ABSOLUTE
end

local function tryEat(pc, bag, hp, max)
    local slot, data = findFoodSlot(bag)
    if slot == nil then
        log(string.format("HP %.0f/%s but no food in hotbar/backpack", hp, tostring(max or "?")))
        logHotbarOnce(bag)
        return false
    end
    local before = Inv.countOf(bag, data)
    local ok, err = Inv.useFromInventory(pc, bag, slot)
    if not ok then
        log("UseItemFromInventory failed: " .. tostring(err))
        return false
    end
    local thresh = (type(max) == "number" and max > 0)
        and string.format("%.0f%% of max", HP_FRACTION * 100)
        or tostring(HP_ABSOLUTE)
    log(string.format(
        "ate %s at HP %.0f/%s (threshold %s) slot=%d",
        Inv.itemDisplay(data), hp, tostring(max or "?"), thresh, slot
    ))
    S.nextUseAt = os.clock() + USE_COOLDOWN
    if before then
        local after = Inv.countOf(bag, data)
        if after and after >= before then
            log("note: stack count unchanged after use (cooldown or rejected?)")
        end
    end
    return true
end

local function tick()
    local pc = U.localPC()
    if not pc then
        S.world, S.readyAt = nil, nil
        S.loggedSlots = false
        return
    end
    local wkey = U.full(pc)
    pcall(function() wkey = wkey .. "|" .. U.full(pc:GetWorld()) end)
    if wkey ~= S.world then
        S.world, S.readyAt = wkey, os.clock() + 6
        S.loggedSlots = false
    end
    if S.readyAt and os.clock() < S.readyAt then return end
    if U.uiBlocking(pc) then return end

    local pawn = U.playerPawn(pc)
    if not pawn then return end

    local hp, max = healthSnapshot(pawn)
    if not needsHeal(hp, max) then return end

    local bag = U.playerBag(pc)
    if not bag then return end
    if os.clock() < S.nextUseAt then return end

    tryEat(pc, bag, hp, max)
end

local okLoop = pcall(LoopInGameThreadWithDelay, POLL_MS, function()
    local ok, err = pcall(tick)
    if not ok then log("tick error: " .. tostring(err)) end
end)
if not okLoop then
    local queued = false
    LoopAsync(POLL_MS, function()
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

log(string.format(
    "loaded v%s — eat food below %.0f%% max HP (or <%d if max unread); poll %dms",
    VERSION, HP_FRACTION * 100, HP_ABSOLUTE, POLL_MS
))
