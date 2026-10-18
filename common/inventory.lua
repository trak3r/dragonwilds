-- Inventory slot helpers (backpack layout measured by community storage mods, 2026-10).
local U = require("teflonted.util")
local M = {}

-- Hotbar = 0 .. NumberOfQuickActionSlots-1 (usually 8).
-- Backpack continues after that for MaxSlotCount slots total.
-- Was hardcoded to 31 (3 backpack rows); row 4 is slots 32–39 on a 40-slot bag.
M.BAG_SLOT_HARD_MAX = 127

function M.quickSlots(bag)
    local n = 0
    pcall(function() n = bag.NumberOfQuickActionSlots end)
    if type(n) ~= "number" or n < 0 or n > 64 then n = 8 end
    return n
end

function M.slotCount(inv)
    local m = 0
    pcall(function() m = inv.MaxSlotCount end)
    if type(m) ~= "number" or m <= 0 or m > 2000 then return 0 end
    return m
end

-- Last usable index on this inventory (respects MaxSlotCount; clamps nonsense).
function M.mainLast(inv)
    local n = M.slotCount(inv)
    if n <= 0 then return -1 end
    return math.min(n, M.BAG_SLOT_HARD_MAX + 1) - 1
end

-- Deprecated alias kept so older call sites keep working until updated.
M.BAG_MAIN_LAST = 39

function M.readSlot(inv, i)
    local it = nil
    local ok = pcall(function() it = inv:GetItemFromSlot(i) end)
    if not ok then return false, nil, 0 end
    if not U.valid(it) then return true, nil, 0 end
    local d, n = nil, 0
    pcall(function() d = it.ItemData end)
    pcall(function() n = inv:GetNumItemsInSlot(i) end)
    if U.valid(d) and type(n) == "number" and n > 0 then return true, d, n end
    return true, nil, 0
end

function M.countOf(inv, data)
    local n = nil
    local ok = pcall(function() n = inv:GetNumItemsByData(data) end)
    if not ok then return nil end
    return tonumber(n)
end

function M.fullName(data)
    return U.full(data)
end

function M.itemDisplay(data)
    local n = nil
    pcall(function() n = data.DisplayName:ToString() end)
    if type(n) == "string" and n ~= "" then return n end
    return U.fname(data)
end

function M.pickDest(inv, key, cap, first, last)
    local matchWithRoom, firstEmpty = nil, nil
    local hi = M.slotCount(inv) - 1
    if last and last < hi then hi = last end
    for i = first or 0, hi do
        local ok, d, n = M.readSlot(inv, i)
        if ok then
            if d and M.fullName(d) == key then
                if matchWithRoom == nil and (not cap or n < cap) then matchWithRoom = i end
            elseif d == nil and firstEmpty == nil then
                firstEmpty = i
            end
        end
    end
    local dst = matchWithRoom or firstEmpty
    if dst == nil then return nil, 0 end
    if not cap then return dst, nil end
    local _, _, n = M.readSlot(inv, dst)
    return dst, cap - (n or 0)
end

-- Move amount from (src,slot) into dst. Returns measured count that left the source.
function M.moveOne(src, slot, dst, data, want, pawn, first, last)
    local key = M.fullName(data)
    local ok, d, n = M.readSlot(src, slot)
    if not ok or not d or M.fullName(d) ~= key then return 0 end
    local amount = math.min(n, want)
    local space = nil
    pcall(function() space = dst:GetSpaceAvailableForItemByData(data) end)
    if type(space) == "number" and amount > space then amount = space end
    if amount <= 0 then return 0 end
    local can = nil
    pcall(function() can = dst:CanAddItemByData(data, amount) end)
    if can ~= true then return 0 end
    local cap = nil
    pcall(function() cap = data.MaxStackSize end)
    if type(cap) ~= "number" or cap <= 0 then cap = nil end
    local to, room = M.pickDest(dst, key, cap, first, last)
    if to == nil then return 0 end
    if room ~= nil then
        if room <= 0 then return 0 end
        if amount > room then amount = room end
    end
    if not U.valid(pawn) then return 0 end
    local before, after = nil, nil
    pcall(function() before = src:GetNumItemsInSlot(slot) end)
    pcall(function() src:MoveItem(slot, dst, to, pawn, amount) end)
    pcall(function() after = src:GetNumItemsInSlot(slot) end)
    if type(before) == "number" and type(after) == "number" and before > after then
        return before - after
    end
    return 0
end

function M.useFromInventory(pc, inv, slot)
    local ic = nil
    pcall(function() ic = pc.BP_Components_InventoryController end)
    if not U.valid(ic) then return false, "no InventoryController" end
    local ok, err = pcall(function() ic:UseItemFromInventory(inv, slot) end)
    if not ok then return false, tostring(err) end
    return true
end

return M
