-- Teflon Ted's Auto Potion — RuneScape: Dragonwilds (UE4SS)
-- When poisoned, automatically drink one antipoison potion from inventory.
-- Skips while an antipoison dose is still in effect (resistance buff).
-- One job only (antipoison). No config.

local TAG = "[TeflonTed.AutoPotion] "
local VERSION = "1.0.1"
local POLL_MS = 750
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
local Potion = require("teflonted.potion")
local Status = require("teflonted.status")

local function log(msg)
    print(TAG .. tostring(msg) .. "\n")
end

local S = {
    nextUseAt = 0,
    buffUntil = 0, -- wall-clock: don't drink again until antipoison perk should expire
    readyAt = nil,
    world = nil,
    dumped = false,
    loggedSlots = false,
    lastWarn = 0,
    lastPoisonLog = 0,
    lastSkipLog = 0,
}

local function findAntipoisonSlot(bag)
    local last = Inv.mainLast(bag)
    local bestSlot, bestData, bestRank = nil, nil, 999
    for i = 0, last do
        local ok, d, n = Inv.readSlot(bag, i)
        if ok and d and n and n > 0 then
            local rank = Potion.antipoisonRank(d)
            if rank > 0 and rank < bestRank then
                bestSlot, bestData, bestRank = i, d, rank
            end
        end
    end
    return bestSlot, bestData
end

local function logInvOnce(bag)
    if S.loggedSlots then return end
    S.loggedSlots = true
    local last = Inv.mainLast(bag)
    local any = false
    for i = 0, last do
        local ok, d, n = Inv.readSlot(bag, i)
        if ok and d and n and n > 0 and Potion.isAntipoison(d) then
            any = true
            log(string.format("antipoison inv[%d] x%d %s", i, n, Potion.describe(d)))
        end
    end
    if not any then
        log("no antipoison potions found in hotbar/backpack (need Weak/Lesser/Antipoison Potion)")
    end
end

--- True when a prior dose should still be granting resistance.
local function antipoisonStillActive(pc)
    if os.clock() < (S.buffUntil or 0) then
        return true, "lockout"
    end
    local live = Potion.hasActiveAntipoison(pc)
    if live == true then
        return true, "active-slot"
    end
    return false, nil
end

local function tryDrink(pc, bag, amount)
    local slot, data = findAntipoisonSlot(bag)
    if slot == nil then
        if os.clock() - S.lastWarn > 15 then
            S.lastWarn = os.clock()
            log(string.format("poisoned (amount=%s) but no antipoison in inventory", tostring(amount)))
            logInvOnce(bag)
        end
        return false
    end
    local before = Inv.countOf(bag, data)
    local ok, err = Inv.useFromInventory(pc, bag, slot)
    if not ok then
        log("UseItemFromInventory failed: " .. tostring(err))
        return false
    end

    local duration = Potion.buffDurationSeconds(data)
    if duration > 0 then
        -- Don't re-quaff while this dose's resistance perk should still be up.
        -- (Poison can rebuild under 33%/66% resist; drinking again would waste pots.)
        S.buffUntil = os.clock() + duration
    end
    S.nextUseAt = os.clock() + USE_COOLDOWN

    log(string.format(
        "drank %s for poison (amount was %s) slot=%d; skip further drinks for %ds",
        Inv.itemDisplay(data), tostring(amount), slot, duration
    ))
    if before then
        local after = Inv.countOf(bag, data)
        if after and after >= before then
            log("note: stack count unchanged after use (async count or rejected?)")
        end
    end
    return true
end

local function tick()
    local pc = U.localPC()
    if not pc then
        S.world, S.readyAt = nil, nil
        Status.reset()
        S.dumped, S.loggedSlots = false, false
        S.buffUntil = 0
        return
    end

    local wkey = U.full(pc)
    pcall(function() wkey = wkey .. "|" .. U.full(pc:GetWorld()) end)
    if wkey ~= S.world then
        S.world, S.readyAt = wkey, os.clock() + 5
        Status.reset()
        S.dumped, S.loggedSlots = false, false
        S.buffUntil = 0
    end
    if S.readyAt and os.clock() < S.readyAt then return end
    if U.uiBlocking(pc) then return end

    local pawn = U.playerPawn(pc)
    if not pawn then return end
    local hp = U.readAttr(pawn, "HealthAttribute")
    if hp ~= nil and hp <= 0 then return end

    if not S.dumped then
        S.dumped = true
        Status.dump(pc, log)
        Potion.dumpActive(pc, log)
        local bag = U.playerBag(pc)
        if bag then logInvOnce(bag) end
    end

    local bag = U.playerBag(pc)
    if not bag then return end
    if os.clock() < S.nextUseAt then return end

    local poisoned, amount = Status.isPoisoned(pc)
    if poisoned == nil then
        if os.clock() - S.lastWarn > 30 then
            S.lastWarn = os.clock()
            log("poison status unread — status component/API missing?")
            Status.reset()
            Status.dump(pc, log)
        end
        return
    end
    if not poisoned then return end

    local active, why = antipoisonStillActive(pc)
    if active then
        if os.clock() - S.lastSkipLog > 20 then
            S.lastSkipLog = os.clock()
            local left = math.max(0, (S.buffUntil or 0) - os.clock())
            log(string.format(
                "poisoned (amount=%s) but antipoison still in effect (%s, ~%.0fs left) — not drinking",
                tostring(amount), tostring(why), left
            ))
        end
        return
    end

    if os.clock() - S.lastPoisonLog > 8 then
        S.lastPoisonLog = os.clock()
        log(string.format("poisoned amount=%s — looking for antipoison", tostring(amount)))
    end
    tryDrink(pc, bag, amount)
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
    "loaded v%s — drink antipoison when poisoned; skip while dose still active (poll %dms)",
    VERSION, POLL_MS
))
