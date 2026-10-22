-- Potion helpers (antipoison detection for AutoPotion).
local U = require("teflonted.util")
local M = {}

-- Wiki durations for the Antipoison / Antipoison II perks.
local DURATION_WEAK = 300
local DURATION_LESSER = 600
local DURATION_II = 300

local function tryCall(obj, name, ...)
    if not U.valid(obj) then return nil end
    local n = select("#", ...)
    local a, b = ...
    local ok, v = pcall(function()
        if obj[name] == nil then return nil end
        if n == 0 then return obj[name](obj) end
        if n == 1 then return obj[name](obj, a) end
        return obj[name](obj, a, b)
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

local function textBlob(data)
    if data == nil then return "" end
    if type(data) == "string" then return data:lower() end
    local parts = {}
    if U.valid(data) then
        parts[#parts + 1] = U.full(data):lower()
        parts[#parts + 1] = U.fname(data):lower()
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
    else
        local s = tostring(data)
        if type(s) == "string" then parts[#parts + 1] = s:lower() end
        if type(data) == "table" then
            for _, k in ipairs({ "ItemData", "PotionData", "SpellData", "Data", "Effect", "Name", "Tag" }) do
                local v = data[k]
                if v ~= nil then parts[#parts + 1] = textBlob(v) end
            end
        end
    end
    return table.concat(parts, " ")
end

--- Prefer weaker pots first so stronger resistance is saved for swamp travel.
local function antipoisonRank(blob)
    -- Must be antipoison (not weapon poison / poison ichor reagents).
    if not blob:find("antipoison", 1, true) then return 0 end
    if blob:find("weapon", 1, true) then return 0 end
    if blob:find("ichor", 1, true) and not blob:find("potion", 1, true) then return 0 end
    -- Rank: weak=1 (use first), lesser=2, plain/II=3 (use last)
    if blob:find("weak", 1, true) then return 1 end
    if blob:find("lesser", 1, true) then return 2 end
    return 3
end

function M.isAntipoison(data)
    if not U.valid(data) then return false end
    return antipoisonRank(textBlob(data)) > 0
end

function M.antipoisonRank(data)
    if not U.valid(data) then return 0 end
    return antipoisonRank(textBlob(data))
end

--- Seconds the Antipoison perk lasts after drinking this item (wiki).
function M.buffDurationSeconds(data)
    local rank = M.antipoisonRank(data)
    if rank <= 0 then return 0 end
    if rank == 2 then return DURATION_LESSER end
    if rank == 1 then return DURATION_WEAK end
    return DURATION_II
end

function M.describe(data)
    if not U.valid(data) then return "invalid" end
    local blob = textBlob(data)
    return string.format("%s antipoisonRank=%d", U.fname(data), antipoisonRank(blob))
end

local function isPotionComp(obj)
    if not U.valid(obj) then return false end
    local full = U.full(obj)
    if full == "" or full:find("Default__", 1, true) then return false end
    if full:find("ScriptStruct", 1, true) or full:find("ComponentReference", 1, true) then
        return false
    end
    return full:find("Potion", 1, true) ~= nil
        or tryProp(obj, "ActivePotionSlots") ~= nil
        or tryProp(obj, "ActivePotions") ~= nil
end

function M.potionComponent(pc)
    local pawn = U.playerPawn(pc)
    if not U.valid(pawn) then return nil end
    local c = tryCall(pawn, "GetPotionComponent")
    if isPotionComp(c) then return c end
    for _, n in ipairs({ "PotionComponent", "BP_Components_Potion", "BP_PotionComponent" }) do
        c = tryProp(pawn, n)
        if isPotionComp(c) then return c end
    end
    return nil
end

local function forEachContainer(container, fn)
    if container == nil or type(container) == "number" or type(container) == "string" then return end
    if type(container) == "table" then
        for k, v in pairs(container) do fn(k, v) end
        return
    end
    if tryProp(container, "ForEach") ~= nil then
        local ok = pcall(function()
            container:ForEach(function(a, b)
                if b == nil then fn(nil, a) else fn(a, b) end
            end)
        end)
        if ok then return end
    end
    local n = tryCall(container, "GetArrayNum")
    if type(n) ~= "number" then pcall(function() n = #container end) end
    if type(n) == "number" and n > 0 and n < 64 then
        for i = 1, n do
            local ok, entry = pcall(function() return container[i] end)
            if ok then fn(i, entry) end
        end
    end
end

local function entryLooksAntipoison(entry)
    if entry == nil then return false end
    if type(entry) == "boolean" or type(entry) == "number" then return false end
    local blob = textBlob(entry)
    if antipoisonRank(blob) > 0 then return true end
    if type(entry) == "table" or U.valid(entry) then
        for _, field in ipairs({
            "ItemData", "PotionData", "Data", "Effect", "GameplayEffect",
            "SourceItem", "ConsumableData", "RowName", "Tag",
        }) do
            local v = tryProp(entry, field)
            if v == nil and type(entry) == "table" then v = entry[field] end
            if v ~= nil and antipoisonRank(textBlob(v)) > 0 then return true end
        end
    end
    return false
end

--- True if PotionComponent still lists an antipoison buff/slot as active.
function M.hasActiveAntipoison(pc)
    local comp = M.potionComponent(pc)
    if not U.valid(comp) then return nil end -- unknown
    local found = false
    for _, field in ipairs({ "ActivePotionSlots", "ActivePotions", "PotionEffectHandles" }) do
        forEachContainer(tryProp(comp, field), function(_, entry)
            if entryLooksAntipoison(entry) then found = true end
        end)
        if found then return true end
    end
    return false
end

function M.dumpActive(pc, log)
    log = log or print
    local comp = M.potionComponent(pc)
    log(string.format("potionComp=%s", U.valid(comp) and U.full(comp) or "nil"))
    if not U.valid(comp) then return end
    for _, field in ipairs({ "ActivePotionSlots", "ActivePotions", "PotionEffectHandles" }) do
        local c = tryProp(comp, field)
        local count = 0
        forEachContainer(c, function(_, entry)
            count = count + 1
            if count <= 8 then
                log(string.format("  %s[%d] antipoison=%s blob=%s",
                    field, count, tostring(entryLooksAntipoison(entry)),
                    textBlob(entry):sub(1, 80)))
            end
        end)
        log(string.format("  %s count~=%d type=%s", field, count, type(c)))
    end
end

return M
