-- Food / drink detection for AutoEat.
-- Identifies ItemData that restores sustenance or hydration (never packs/potions-only).
local U = require("teflonted.util")
local M = {}

local SUST_FIELDS = {
    "SustenanceToAdd", "SustenanceAmount", "SustenanceRestored", "RestoredSustenance",
    "FoodSustenance", "Sustenance", "HungerRestore", "FoodAmount",
}
local HYDR_FIELDS = {
    "HydrationToAdd", "HydrationAmount", "HydrationRestored", "RestoredHydration",
    "DrinkHydration", "Hydration", "ThirstRestore", "DrinkAmount",
}

local function numField(data, name)
    local v = nil
    pcall(function() v = data[name] end)
    if type(v) == "number" then return v end
    -- Some values live under a nested struct.
    pcall(function()
        local d = data.Data
        if d then v = d[name] end
    end)
    if type(v) == "number" then return v end
    return nil
end

local function classLooksLike(data, needle)
    local c = nil
    pcall(function() c = data:GetClass() end)
    for _ = 1, 12 do
        if not U.valid(c) then break end
        local n = ""
        pcall(function() n = c:GetFName():ToString() end)
        if n:lower():find(needle, 1, true) then return true end
        if n == "Object" then break end
        pcall(function() c = c:GetSuperStruct() end)
    end
    local path = U.full(data):lower()
    return path:find(needle, 1, true) ~= nil
end

local function isPackOrEmitter(data)
    local n = U.fname(data)
    if n == "BP_Consumables_ItemEmitter_C" then return true end
    if classLooksLike(data, "itememitter") then return true end
    return false
end

local function isPotionOnly(data, sust, hyd)
    -- Potions often restore neither bar (or only buffs). Prefer excluding obvious potion paths
    -- when both sust/hyd are zero.
    if (sust or 0) > 0 or (hyd or 0) > 0 then return false end
    local path = U.full(data):lower()
    if path:find("potion", 1, true) then return true end
    if classLooksLike(data, "potion") then return true end
    return false
end

function M.restoreAmounts(data)
    if not U.valid(data) then return 0, 0 end
    local sust, hyd = 0, 0
    for _, f in ipairs(SUST_FIELDS) do
        local v = numField(data, f)
        if v and v > sust then sust = v end
    end
    for _, f in ipairs(HYDR_FIELDS) do
        local v = numField(data, f)
        if v and v > hyd then hyd = v end
    end
    -- Class / path fallback when numeric fields are opaque on this build.
    if sust <= 0 and (classLooksLike(data, "food") or classLooksLike(data, "meal") or classLooksLike(data, "cooked")) then
        sust = 1
    end
    if hyd <= 0 and (classLooksLike(data, "drink") or classLooksLike(data, "water") or classLooksLike(data, "beverage")) then
        hyd = 1
    end
    return sust, hyd
end

-- kind: "food" | "drink"
function M.isKind(data, kind)
    if not U.valid(data) or isPackOrEmitter(data) then return false end
    local sust, hyd = M.restoreAmounts(data)
    if isPotionOnly(data, sust, hyd) then return false end
    if kind == "food" then return sust > 0 end
    if kind == "drink" then return hyd > 0 end
    return false
end

return M
