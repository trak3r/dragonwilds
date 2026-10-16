-- Shared helpers for Teflon Ted Dragonwilds UE4SS mods.
local M = {}

function M.valid(o)
    if not o then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end

function M.full(o)
    if not M.valid(o) then return "" end
    local ok, n = pcall(function() return o:GetFullName() end)
    return ok and tostring(n) or ""
end

function M.fname(o)
    if not M.valid(o) then return "" end
    local ok, n = pcall(function() return o:GetFName():ToString() end)
    return ok and tostring(n) or ""
end

function M.isA(obj, className)
    if not M.valid(obj) then return false end
    local c = nil
    pcall(function() c = obj:GetClass() end)
    for _ = 1, 16 do
        if not M.valid(c) then return false end
        local n = ""
        pcall(function() n = c:GetFName():ToString() end)
        if n == className or n == (className .. "_C") then return true end
        if n == "Object" or n == "Actor" then return false end
        pcall(function() c = c:GetSuperStruct() end)
    end
    return false
end

-- Cached local PlayerController. Avoids FindAllOf every tick (that hitch).
local cachedPC, nextPCScan = nil, 0
function M.localPC()
    if M.valid(cachedPC) then
        local okL, isLocal = pcall(function() return cachedPC:IsLocalController() end)
        if okL and isLocal then return cachedPC end
    end
    cachedPC = nil
    local now = os.clock()
    if now < nextPCScan then return nil end
    nextPCScan = now + 3
    local ok, all = pcall(FindAllOf, "PlayerController")
    if not ok or not all then
        nextPCScan = now + 10
        return nil
    end
    for _, pc in ipairs(all) do
        if M.valid(pc) then
            local n = M.full(pc)
            local okL, isLocal = pcall(function() return pc:IsLocalController() end)
            if not n:find("MainMenu", 1, true) and not n:find("Default__", 1, true) and okL and isLocal then
                cachedPC = pc
                nextPCScan = now + 3
                return pc
            end
        end
    end
    nextPCScan = now + 10
    return nil
end

function M.playerPawn(pc)
    if not M.valid(pc) then return nil end
    local p = nil
    pcall(function() p = pc.Pawn end)
    if not M.valid(p) then return nil end
    if M.isA(p, "DominionPlayerCharacter") then return p end
    return nil
end

function M.playerBag(pc)
    if not M.valid(pc) then return nil end
    local b = nil
    pcall(function() b = pc.BP_Components_Inventory end)
    return M.valid(b) and b or nil
end

function M.isHost(pc)
    local h = nil
    local ok = pcall(function() h = pc:HasAuthority() end)
    return ok and h == true
end

function M.uiBlocking(pc)
    if not M.valid(pc) then return true end
    local cur = nil
    pcall(function() cur = pc.bShowMouseCursor end)
    return cur == true
end

function M.readAttr(pawn, attrClassName)
    if not M.valid(pawn) then return nil end
    local attrLib = StaticFindObject("/Script/Dominion.Default__AttributeFunctionLibrary")
    local attrCls = StaticFindObject("/Script/Dominion." .. attrClassName)
    if not (M.valid(attrLib) and M.valid(attrCls)) then return nil end
    local out, out2 = {}, {}
    local ok = pcall(function()
        attrLib:BP_TryGetFloatAttributeValue(pawn, attrCls, 0.0, out, out2)
    end)
    if not ok then return nil end
    local v, found = out.OutAttributeValue, out.OutbFound
    if type(v) ~= "number" then v, found = out2.OutAttributeValue, out2.OutbFound end
    if found == false then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

-- Try to read a numeric field/method from an object.
-- UE4SS UFunctions must be called with obj:Name() syntax; indexing often yields a TrivialObject.
function M.readNumber(obj, names)
    if not M.valid(obj) then return nil end
    for _, name in ipairs(names) do
        -- Method call first (GetSustenance / GetHydration / …)
        local okm, vm = pcall(function()
            local fn = obj[name]
            if fn ~= nil then return obj[name](obj) end
        end)
        if okm and type(vm) == "number" then return vm end
        -- Plain property
        local okp, vp = pcall(function() return obj[name] end)
        if okp and type(vp) == "number" then return vp end
    end
    return nil
end

return M
