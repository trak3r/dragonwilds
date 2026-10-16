-- Food / drink detection for AutoEat.
local U = require("teflonted.util")
local M = {}

local SUST_FIELDS = {
    "SustenanceToAdd", "SustenanceAmount", "SustenanceRestored", "RestoredSustenance",
    "FoodSustenance", "Sustenance", "HungerRestore", "FoodAmount", "ConsumedSustenance",
    "SustenanceRestore", "RestoreSustenance",
}
local HYDR_FIELDS = {
    "HydrationToAdd", "HydrationAmount", "HydrationRestored", "RestoredHydration",
    "DrinkHydration", "Hydration", "ThirstRestore", "DrinkAmount", "ConsumedHydration",
    "HydrationRestore", "RestoreHydration",
}

local function numField(data, name)
    local v = nil
    pcall(function() v = data[name] end)
    if type(v) == "number" then return v end
    pcall(function()
        local d = data.Data
        if d then v = d[name] end
    end)
    if type(v) == "number" then return v end
    return nil
end

local function textBlob(data)
    local parts = { U.full(data):lower(), U.fname(data):lower() }
    local dn = nil
    pcall(function() dn = data.DisplayName:ToString() end)
    if type(dn) == "string" then parts[#parts + 1] = dn:lower() end
    local c = nil
    pcall(function() c = data:GetClass() end)
    for _ = 1, 10 do
        if not U.valid(c) then break end
        local n = ""
        pcall(function() n = c:GetFName():ToString() end)
        parts[#parts + 1] = n:lower()
        if n == "Object" then break end
        pcall(function() c = c:GetSuperStruct() end)
    end
    return table.concat(parts, " ")
end

local function blobHas(blob, words)
    for _, w in ipairs(words) do
        if blob:find(w, 1, true) then return true end
    end
    return false
end

local function isPackOrEmitter(data)
    local n = U.fname(data)
    if n == "BP_Consumables_ItemEmitter_C" then return true end
    local blob = textBlob(data)
    return blob:find("itememitter", 1, true) ~= nil
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
    local blob = textBlob(data)
    -- Path / name heuristics when numeric fields aren't exposed to Lua.
    if sust <= 0 and blobHas(blob, { "food", "meal", "cooked", "meat", "fish", "bread", "stew", "ration", "berry", "fruit" }) then
        sust = 1
    end
    if hyd <= 0 and blobHas(blob, { "drink", "water", "beverage", "flask", "potion_of_water", "hydration", "tea", "ale", "beer", "wine", "juice" }) then
        hyd = 1
    end
    -- Pure combat/buff potions: name has potion but no water/drink/food signals and no restores.
    if sust <= 0 and hyd <= 0 and blob:find("potion", 1, true) then
        return 0, 0
    end
    return sust, hyd
end

function M.isKind(data, kind)
    if not U.valid(data) or isPackOrEmitter(data) then return false end
    local sust, hyd = M.restoreAmounts(data)
    if kind == "food" then return sust > 0 end
    if kind == "drink" then return hyd > 0 end
    return false
end

-- Debug helper: describe why an item was/wasn't classified.
function M.describe(data)
    if not U.valid(data) then return "invalid" end
    local sust, hyd = M.restoreAmounts(data)
    return string.format("%s sust=%.0f hyd=%.0f", U.fname(data), sust, hyd)
end

return M
