-- Read sustenance / hydration via SustenanceComponent / HydrationComponent
-- (symbol names confirmed in RSDragonwilds-Win64-Shipping.exe).
local U = require("teflonted.util")
local M = {}

local S = {
    sustComp = nil,
    hydrComp = nil,
    dumped = false,
    discovered = false,
}

local function callNum(obj, method)
    if not U.valid(obj) then return nil end
    local ok, v = pcall(function() return obj[method](obj) end)
    if ok and type(v) == "number" then return v end
    return nil
end

local function readSust(comp)
    if not U.valid(comp) then return nil end
    local v = callNum(comp, "GetSustenance")
    if v ~= nil then return v end
    return U.readNumber(comp, { "CurrentSustenance", "CurrentValue", "Value", "Sustenance" })
end

local function readHydr(comp)
    if not U.valid(comp) then return nil end
    local v = callNum(comp, "GetHydration")
    if v ~= nil then return v end
    return U.readNumber(comp, { "CurrentHydration", "CurrentValue", "Value", "Hydration" })
end

local function findOwned(pawn, className)
    local ok, all = pcall(FindAllOf, className)
    if not (ok and all) then return nil end
    local pawnName = U.full(pawn)
    for _, o in ipairs(all) do
        if U.valid(o) and not U.full(o):find("Default__", 1, true) then
            local owner = nil
            pcall(function() owner = o:GetOwner() end)
            if U.valid(owner) and U.full(owner) == pawnName then
                return o
            end
            -- Some builds attach under the controller / outer chain.
            local outer = nil
            pcall(function() outer = o:GetOuter() end)
            if U.valid(outer) and (U.full(outer) == pawnName or U.isA(outer, "DominionPlayerCharacter")) then
                return o
            end
        end
    end
    -- Fallback: first non-default instance (solo).
    for _, o in ipairs(all) do
        if U.valid(o) and not U.full(o):find("Default__", 1, true) then
            return o
        end
    end
    return nil
end

local function fromPawnDirect(pawn)
    local s = callNum(pawn, "GetSustenance")
        or U.readNumber(pawn, { "CurrentSustenance", "Sustenance" })
    local h = callNum(pawn, "GetHydration")
        or U.readNumber(pawn, { "CurrentHydration", "Hydration" })
    return s, h
end

local function fromPawnProps(pawn)
    for _, n in ipairs({ "SustenanceComponent", "BP_SustenanceComponent", "BP_Components_Sustenance" }) do
        local ok, c = pcall(function() return pawn[n] end)
        if ok and U.valid(c) and readSust(c) ~= nil then return c, nil end
    end
    local sust, hydr = nil, nil
    for _, n in ipairs({ "SustenanceComponent", "BP_SustenanceComponent", "BP_Components_Sustenance" }) do
        local ok, c = pcall(function() return pawn[n] end)
        if ok and U.valid(c) then sust = c; break end
    end
    for _, n in ipairs({ "HydrationComponent", "BP_HydrationComponent", "BP_Components_Hydration" }) do
        local ok, c = pcall(function() return pawn[n] end)
        if ok and U.valid(c) then hydr = c; break end
    end
    return sust, hydr
end

function M.discover(pawn, log)
    log = log or function() end
    if not S.dumped then
        S.dumped = true
        log("discovering SustenanceComponent / HydrationComponent")
    end

    local ps, ph = fromPawnProps(pawn)
    S.sustComp = ps or findOwned(pawn, "SustenanceComponent")
    S.hydrComp = ph or findOwned(pawn, "HydrationComponent")

    local ds, dh = fromPawnDirect(pawn)
    local vs = readSust(S.sustComp)
    local vh = readHydr(S.hydrComp)

    if U.valid(S.sustComp) then
        log("SustenanceComponent=" .. U.full(S.sustComp) .. " value=" .. tostring(vs))
    else
        log("SustenanceComponent not found")
    end
    if U.valid(S.hydrComp) then
        log("HydrationComponent=" .. U.full(S.hydrComp) .. " value=" .. tostring(vh))
    else
        log("HydrationComponent not found")
    end
    if ds ~= nil or dh ~= nil then
        log(string.format("pawn direct GetSustenance/GetHydration = %s / %s", tostring(ds), tostring(dh)))
    end

    S.discovered = true
    local ok = (vs ~= nil or ds ~= nil) and (vh ~= nil or dh ~= nil)
    if not ok then
        log("WARNING: could not read both bars yet")
    end
    return ok
end

function M.read(pawn)
    if not U.valid(pawn) then return nil, nil end

    -- Prefer direct pawn getters if present (no FindAllOf).
    local ds, dh = fromPawnDirect(pawn)
    if ds ~= nil or dh ~= nil then
        return ds, dh
    end

    if not U.valid(S.sustComp) then
        S.sustComp = findOwned(pawn, "SustenanceComponent")
    end
    if not U.valid(S.hydrComp) then
        S.hydrComp = findOwned(pawn, "HydrationComponent")
    end
    return readSust(S.sustComp), readHydr(S.hydrComp)
end

function M.reset()
    S.sustComp, S.hydrComp = nil, nil
    S.dumped, S.discovered = false, false
end

function M.isDiscovered()
    return S.discovered == true
end

return M
