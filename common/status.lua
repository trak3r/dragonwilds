-- Tracked status effects (poison, etc.) via TrackedStatusEffectsComponent.
-- Enum order from shipping binary (ETrackedStatusEffect::*).
local U = require("teflonted.util")
local M = {}

-- ETrackedStatusEffect::None=0, Cold=1, Poison=2, ...
M.Effect = {
    None = 0,
    Cold = 1,
    Poison = 2,
    Burning = 3,
    Bleeding = 4,
    Slow = 5,
    WellRested = 6,
    Cosiness = 7,
    Wither = 8,
    Scorch = 9,
    AnimaCharge = 10,
    SoulScourge = 11,
    Shocked = 12,
    Chilled = 13,
    SlowBuildup = 14,
    OverEating = 15,
    Hamstrung = 16,
}

local cachedComp = nil

local function tryCall(obj, name, ...)
    if not U.valid(obj) then return nil end
    local n = select("#", ...)
    local a, b, c = ...
    local ok, v = pcall(function()
        if obj[name] == nil then return nil end
        if n == 0 then return obj[name](obj) end
        if n == 1 then return obj[name](obj, a) end
        if n == 2 then return obj[name](obj, a, b) end
        return obj[name](obj, a, b, c)
    end)
    if ok then return v end
    return nil
end

local function tryProp(obj, name)
    if not U.valid(obj) then return nil end
    local ok, v = pcall(function() return obj[name] end)
    if ok then return v end
    return nil
end

local function isStatusComp(obj)
    if not U.valid(obj) then return false end
    local full = U.full(obj)
    if full == "" or full:find("Default__", 1, true) then return false end
    if full:find("ScriptStruct", 1, true) or full:find("ComponentReference", 1, true) then
        return false
    end
    return tryProp(obj, "GetTrackedStatusEffectAmount") ~= nil
        or tryProp(obj, "GetTrackedStatusEffect") ~= nil
        or full:find("TrackedStatus", 1, true) ~= nil
end

local function findOwned(pawn, className)
    local ok, all = pcall(FindAllOf, className)
    if not (ok and all) then return nil end
    local pawnName = U.full(pawn)
    for _, o in ipairs(all) do
        if isStatusComp(o) then
            local owner = nil
            pcall(function() owner = o:GetOwner() end)
            if U.valid(owner) and U.full(owner) == pawnName then return o end
            local outer = nil
            pcall(function() outer = o:GetOuter() end)
            if U.valid(outer) and U.full(outer) == pawnName then return o end
        end
    end
    for _, o in ipairs(all) do
        if isStatusComp(o) then return o end
    end
    return nil
end

function M.reset()
    cachedComp = nil
end

function M.statusComponent(pc, pawn)
    if U.valid(cachedComp) then return cachedComp end
    pawn = pawn or U.playerPawn(pc)
    if not U.valid(pawn) then return nil end

    local c = tryCall(pawn, "GetTrackedStatusEffectsComponent")
    if isStatusComp(c) then
        cachedComp = c
        return c
    end
    for _, n in ipairs({
        "TrackedStatusEffectsComponent",
        "BP_Components_TrackedStatusEffects",
        "BP_TrackedStatusEffectsComponent",
    }) do
        c = tryProp(pawn, n)
        if isStatusComp(c) then
            cachedComp = c
            return c
        end
    end
    c = findOwned(pawn, "TrackedStatusEffectsComponent")
    if isStatusComp(c) then
        cachedComp = c
        return c
    end
    return nil
end

--- Returns numeric amount for an ETrackedStatusEffect index, or nil if unread.
function M.effectAmount(pc, effectIndex)
    local pawn = U.playerPawn(pc)
    local comp = M.statusComponent(pc, pawn)
    if not U.valid(comp) then return nil end

    local amount = tryCall(comp, "GetTrackedStatusEffectAmount", effectIndex)
    if type(amount) == "number" then return amount end

    -- Some builds return a struct / object from GetTrackedStatusEffect.
    local fx = tryCall(comp, "GetTrackedStatusEffect", effectIndex)
    if type(fx) == "number" then return fx end
    if U.valid(fx) then
        local v = U.readNumber(fx, { "Amount", "Value", "Current", "Stacks", "GetAmount" })
        if type(v) == "number" then return v end
    elseif type(fx) == "table" then
        local v = fx.Amount or fx.Value or fx.Current or fx.Stacks
        if type(v) == "number" then return v end
    end
    return nil
end

function M.isPoisoned(pc)
    local amount = M.effectAmount(pc, M.Effect.Poison)
    if type(amount) == "number" then return amount > 0.01, amount end
    return nil, nil -- unknown (component/API missing)
end

function M.dump(pc, log)
    log = log or print
    local pawn = U.playerPawn(pc)
    local comp = M.statusComponent(pc, pawn)
    log(string.format("statusComp=%s", U.valid(comp) and U.full(comp) or "nil"))
    if not U.valid(comp) then return end
    for name, idx in pairs(M.Effect) do
        if name ~= "None" and type(idx) == "number" and idx < 17 then
            local a = tryCall(comp, "GetTrackedStatusEffectAmount", idx)
            if type(a) == "number" and a ~= 0 then
                log(string.format("  effect[%s=%d] amount=%s", name, idx, tostring(a)))
            end
        end
    end
    -- Always log poison explicitly.
    local p = tryCall(comp, "GetTrackedStatusEffectAmount", M.Effect.Poison)
    log(string.format("  Poison(%d) amount=%s", M.Effect.Poison, tostring(p)))
end

return M
