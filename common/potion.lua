-- Potion helpers (antipoison detection for AutoPotion).
local U = require("teflonted.util")
local M = {}

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

function M.describe(data)
    if not U.valid(data) then return "invalid" end
    local blob = textBlob(data)
    return string.format("%s antipoisonRank=%d", U.fname(data), antipoisonRank(blob))
end

return M
