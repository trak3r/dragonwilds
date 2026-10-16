-- Teflon Ted's Auto Eat — RuneScape: Dragonwilds (UE4SS)
-- When sustenance or hydration < 50, consume one food/drink from inventory.

local TAG = "[TeflonTed.AutoEat] "
local VERSION = "1.0.0"
local THRESHOLD = 50
local POLL_MS = 500
local USE_COOLDOWN = 2.25  -- game food/drink gate is ~2 s

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
    warnedAttr = false,
    warnedGuest = false,
    sustAttr = nil,
    hydrAttr = nil,
    readyAt = nil,
    world = nil,
}

local ATTR_CANDIDATES = {
    sustenance = {
        "SustenanceAttribute", "Sustenance", "FoodAttribute", "HungerAttribute",
        "PlayerSustenanceAttribute",
    },
    hydration = {
        "HydrationAttribute", "Hydration", "ThirstAttribute", "WaterAttribute",
        "PlayerHydrationAttribute",
    },
}

local function resolveAttr(pawn, kind)
    local cached = (kind == "sustenance") and S.sustAttr or S.hydrAttr
    if cached then
        local v = U.readAttr(pawn, cached)
        if v ~= nil then return cached, v end
    end
    for _, name in ipairs(ATTR_CANDIDATES[kind]) do
        local v = U.readAttr(pawn, name)
        if v ~= nil then
            if kind == "sustenance" then S.sustAttr = name else S.hydrAttr = name end
            log("using attribute " .. name .. " for " .. kind)
            return name, v
        end
    end
    return nil, nil
end

local function findConsumableSlot(bag, kind)
    local last = math.min(Inv.BAG_MAIN_LAST, Inv.slotCount(bag) - 1)
    -- Prefer hotbar first, then main backpack.
    for i = 0, last do
        local ok, d, n = Inv.readSlot(bag, i)
        if ok and d and n and n > 0 and Food.isKind(d, kind) then
            return i, d
        end
    end
    return nil, nil
end

local function tryConsume(pc, bag, kind, value)
    local slot, data = findConsumableSlot(bag, kind)
    if not slot then
        log(string.format("%s at %.0f but no %s in inventory", kind, value, kind))
        return false
    end
    local before = Inv.countOf(bag, data)
    local ok, err = Inv.useFromInventory(pc, bag, slot)
    if not ok then
        log("UseItemFromInventory failed: " .. tostring(err))
        return false
    end
    local name = Inv.itemDisplay(data)
    log(string.format("used %s for %s (was %.0f)", name, kind, value))
    S.nextUseAt = os.clock() + USE_COOLDOWN
    -- Soft verify: stack should drop if the use consumed a charge.
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
        return
    end
    local wkey = U.full(pc)
    pcall(function() wkey = wkey .. "|" .. U.full(pc:GetWorld()) end)
    if wkey ~= S.world then
        S.world, S.readyAt = wkey, os.clock() + 8
        S.sustAttr, S.hydrAttr = nil, nil
    end
    if S.readyAt and os.clock() < S.readyAt then return end
    if U.uiBlocking(pc) then return end
    local pawn = U.playerPawn(pc)
    if not pawn then return end
    local hp = U.readAttr(pawn, "HealthAttribute")
    if hp ~= nil and hp <= 0 then return end

    if not U.isHost(pc) then
        if not S.warnedGuest then
            S.warnedGuest = true
            log("joined world: AutoEat still tries client UseItemFromInventory; if nothing happens, use solo/host")
        end
    end

    local bag = U.playerBag(pc)
    if not bag then return end
    if os.clock() < S.nextUseAt then return end

    local _, sust = resolveAttr(pawn, "sustenance")
    local _, hydr = resolveAttr(pawn, "hydration")
    if sust == nil and hydr == nil then
        if not S.warnedAttr then
            S.warnedAttr = true
            log("could not read Sustenance/Hydration attributes yet (still loading, or names changed)")
        end
        return
    end

    -- One consume per tick; food first if both low.
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

log("loaded v" .. VERSION .. string.format(" — auto eat/drink below %d", THRESHOLD))
