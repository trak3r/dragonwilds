-- Teflon Ted's Auto Eat — RuneScape: Dragonwilds (UE4SS)
-- When sustenance or hydration < 50, consume one food/drink from inventory.

local TAG = "[TeflonTed.AutoEat] "
local VERSION = "1.1.0"
local THRESHOLD = 50
local POLL_MS = 3000          -- was 500; FindAllOf+attr spam caused ~1s hitches
local USE_COOLDOWN = 2.25

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
local Survival = require("teflonted.survival")

local function log(msg)
    print(TAG .. tostring(msg) .. "\n")
end

local S = {
    nextUseAt = 0,
    readyAt = nil,
    world = nil,
    discoverTries = 0,
    loggedSlots = false,
    lastWarn = 0,
}

local function findConsumableSlot(bag, kind)
    local last = Inv.mainLast(bag)
    for i = 0, last do
        local ok, d, n = Inv.readSlot(bag, i)
        if ok and d and n and n > 0 and Food.isKind(d, kind) then
            return i, d
        end
    end
    return nil, nil
end

local function logHotbarOnce(bag)
    if S.loggedSlots then return end
    S.loggedSlots = true
    local last = Inv.mainLast(bag)
    for i = 0, last do
        local ok, d, n = Inv.readSlot(bag, i)
        if ok and d and n and n > 0 then
            log(string.format("inv[%d] x%d %s", i, n, Food.describe(d)))
        end
    end
end

local function tryConsume(pc, bag, kind, value)
    local slot, data = findConsumableSlot(bag, kind)
    if slot == nil then
        log(string.format("%s at %.1f but no %s found in hotbar/backpack", kind, value, kind))
        logHotbarOnce(bag)
        return false
    end
    local before = Inv.countOf(bag, data)
    local ok, err = Inv.useFromInventory(pc, bag, slot)
    if not ok then
        log("UseItemFromInventory failed: " .. tostring(err))
        return false
    end
    log(string.format("used %s for %s (was %.1f) slot=%d", Inv.itemDisplay(data), kind, value, slot))
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
        Survival.reset()
        S.discoverTries, S.loggedSlots = 0, false
        return
    end
    local wkey = U.full(pc)
    pcall(function() wkey = wkey .. "|" .. U.full(pc:GetWorld()) end)
    if wkey ~= S.world then
        S.world, S.readyAt = wkey, os.clock() + 6
        Survival.reset()
        S.discoverTries, S.loggedSlots = 0, false
    end
    if S.readyAt and os.clock() < S.readyAt then return end
    if U.uiBlocking(pc) then return end

    local pawn = U.playerPawn(pc)
    if not pawn then return end
    local hp = U.readAttr(pawn, "HealthAttribute")
    if hp ~= nil and hp <= 0 then return end

    if not Survival.isDiscovered() then
        if S.discoverTries < 5 then
            S.discoverTries = S.discoverTries + 1
            Survival.discover(pawn, log)
        elseif os.clock() - S.lastWarn > 30 then
            S.lastWarn = os.clock()
            log("still no sustenance/hydration reader; will keep trying slowly")
            S.discoverTries = 0
        else
            return
        end
    end

    local bag = U.playerBag(pc)
    if not bag then return end
    if os.clock() < S.nextUseAt then return end

    local sust, hydr = Survival.read(pawn)
    if sust == nil and hydr == nil then
        if os.clock() - S.lastWarn > 30 then
            S.lastWarn = os.clock()
            log("survival values unread (nil,nil)")
            Survival.reset()
            S.discoverTries = 0
        end
        return
    end

    if sust ~= nil and sust < THRESHOLD then
        tryConsume(pc, bag, "food", sust)
        return
    end
    if hydr ~= nil and hydr < THRESHOLD then
        tryConsume(pc, bag, "drink", hydr)
        return
    end
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

log("loaded v" .. VERSION .. string.format(" — auto eat/drink below %d (poll %dms)", THRESHOLD, POLL_MS))
