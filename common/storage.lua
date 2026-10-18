-- Nearby chest discovery + deposit-matching (sort-into-chests).
local U = require("teflonted.util")
local Inv = require("teflonted.inventory")
local M = {}

-- Hardcoded radius in metres (Valheim workstation-scale; GetDistanceTo returns cm).
M.RADIUS_M = 20

function M.distanceM(pawn, actor)
    local ok, d = pcall(function() return pawn:GetDistanceTo(actor) end)
    if ok and type(d) == "number" then return d / 100 end
    return nil
end

function M.isStation(actor)
    local n = U.fname(actor)
    local chain = U.full(actor)
    return n:find("^BP_Station_") ~= nil or chain:find("BP_Station_", 1, true) ~= nil
end

function M.storageFlags(actor)
    local linkable, private = nil, false
    local lc = nil
    pcall(function() lc = actor.LinkedInventoryComponent end)
    if U.valid(lc) then pcall(function() linkable = lc.bIsLinkable end) end
    local oc = nil
    pcall(function() oc = actor.OwnershipComponent end)
    if U.valid(oc) then pcall(function() private = oc.bIsPrivatelyOwned end) end
    return linkable, private
end

-- Find BaseBuildingActor inventories within radius (chests, not stations).
function M.findNearbyChests(pawn, radiusM)
    local out = {}
    local ok, all = pcall(FindAllOf, "InventoryComponent")
    if not ok or not all then return out end
    for _, inv in ipairs(all) do
        if U.valid(inv) and not U.fname(inv):find("^Default__") then
            local owner = nil
            pcall(function() owner = inv:GetOwner() end)
            if U.valid(owner) and U.isA(owner, "BaseBuildingActor") and not M.isStation(owner) then
                local _, private = M.storageFlags(owner)
                if private ~= true then
                    local dm = M.distanceM(pawn, owner)
                    if dm and dm <= (radiusM or M.RADIUS_M) then
                        out[#out + 1] = { actor = owner, inv = inv, distM = dm }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return (a.distM or 0) < (b.distM or 0) end)
    return out
end

-- Deposit backpack main slots into chests that already hold each item. Returns moved count.
function M.sortIntoChests(pc, pawn, bag, chests)
    local moved = 0
    local skip = Inv.quickSlots(bag)
    local last = Inv.mainLast(bag)
    for i = skip, last do
        local ok, d = Inv.readSlot(bag, i)
        if ok and d then
            local targets = {}
            for _, c in ipairs(chests) do
                local n = Inv.countOf(c.inv, d)
                if n and n > 0 then targets[#targets + 1] = c end
            end
            for _, c in ipairs(targets) do
                for _ = 1, 8 do
                    local _, _, n = Inv.readSlot(bag, i)
                    if not n or n <= 0 then break end
                    local m = Inv.moveOne(bag, i, c.inv, d, n, pawn)
                    if m <= 0 then break end
                    moved = moved + m
                end
            end
        end
    end
    return moved
end

return M
