-- Read active spell cooldowns from Dominion magic components.
-- UE4SS cannot ForEach/pairs TMaps here, so we:
--   1) resolve real magic components (not ComponentReference structs)
--   2) track spells via cast hooks + SpellBeingPrepared* / LastCastTimeBySpellData_Key
--   3) poll GetCooldownTimeLeft / GetCooldownTimeRemaining / CooldownSecondsRemaining
local U = require("teflonted.util")
local M = {}

local GETTERS = {
    "GetPlayerUtilityMagicComponent",
    "GetPlayerCombatMagicComponent",
}

local PROPS = {
    "PlayerUtilityMagicComponent",
    "PlayerCombatMagicComponent",
    -- Prefer live component objects; *Ref is an FComponentReference struct (not the component).
}

local SPELL_PROPS = {
    "SpellBeingPreparedOrCast",
    "SpellBeingPreparedOrCastData",
    "PreviousSpellBeingPreparedOrCast",
    "ReplicatedSpellData",
    "UtilitySpell",
    "CombatSpell",
    "CurrentSpell",
    "ActiveSpell",
}

local NAME_FIELDS = {
    "SpellDisplayName", "DisplayName", "SpellName", "Name",
    "GetSpellDisplayName", "GetDisplayName", "GetSpellName", "GetName",
}

local TIME_FIELDS = {
    "GetCooldownTimeLeft", "GetCooldownTimeRemaining", "CooldownSecondsRemaining",
    "CooldownTimeLeft", "CooldownRemaining", "TimeRemaining", "Remaining",
}

local unpack_ = table.unpack or unpack

-- key -> { spell=UObject|nil, name=string, notedAt=number }
local tracked = {}
local hooksInstalled = false
local logFn = print

local function tryCall(obj, name, ...)
    if not U.valid(obj) then return nil end
    local n = select("#", ...)
    local args = { ... }
    local ok, v = pcall(function()
        if obj[name] == nil then return nil end
        if n == 0 then return obj[name](obj) end
        return obj[name](obj, unpack_(args, 1, n))
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

local function isRealComponent(obj)
    if not U.valid(obj) then return false end
    local full = U.full(obj)
    if full == "" or full:find("Default__", 1, true) then return false end
    if full:find("ScriptStruct", 1, true) then return false end
    if full:find("ComponentReference", 1, true) then return false end
    -- Prefer names that look like magic components.
    local fn = U.fname(obj)
    if fn:find("Magic", 1, true) or full:find("Magic", 1, true) then return true end
    -- Still allow if GetCooldownTimeLeft exists.
    return tryProp(obj, "GetCooldownTimeLeft") ~= nil
        or tryProp(obj, "HandleUtilitySpellCast") ~= nil
end

local function pushUnique(list, obj)
    if not isRealComponent(obj) then return end
    local full = U.full(obj)
    for _, existing in ipairs(list) do
        if existing == obj then return end
        if U.full(existing) == full then return end
    end
    list[#list + 1] = obj
end

function M.magicComponents(pc, pawn)
    local out = {}
    for _, host in ipairs({ pc, pawn }) do
        if U.valid(host) then
            for _, g in ipairs(GETTERS) do
                pushUnique(out, tryCall(host, g))
            end
            for _, p in ipairs(PROPS) do
                pushUnique(out, tryProp(host, p))
            end
        end
    end
    return out
end

local function displayName(obj)
    if not U.valid(obj) then return nil end
    for _, n in ipairs(NAME_FIELDS) do
        local v = tryCall(obj, n)
        if type(v) == "string" and v ~= "" then return v end
        if v ~= nil then
            local ok, ts = pcall(function()
                if type(v.ToString) == "function" or v.ToString then return v:ToString() end
                return tostring(v)
            end)
            if ok and type(ts) == "string" and ts ~= "" and not ts:find("0x", 1, true)
                and not ts:find("UObject", 1, true) and not ts:find("TrivialObject", 1, true) then
                return ts
            end
        end
        local p = tryProp(obj, n)
        if type(p) == "string" and p ~= "" then return p end
        if p ~= nil then
            local ok, ts = pcall(function() return p:ToString() end)
            if ok and type(ts) == "string" and ts ~= "" then return ts end
        end
    end
    local fn = U.fname(obj)
    if fn ~= "" then
        return fn:gsub("_C$", ""):gsub("^BP_", ""):gsub("^DA_", ""):gsub("^WBP_", "")
    end
    return nil
end

local function spellKey(spell)
    if not U.valid(spell) then return nil end
    local full = U.full(spell)
    if full ~= "" then return full end
    local fn = U.fname(spell)
    if fn ~= "" then return fn end
    return nil
end

function M.noteSpell(spell, nameHint)
    local key = spellKey(spell)
    if not key then return end
    local name = nameHint or displayName(spell) or U.fname(spell) or "Spell"
    tracked[key] = { spell = spell, name = name, notedAt = os.clock() }
end

local function noteFromHook(tag, a, b, c)
    local candidates = { a, b, c }
    for _, cand in ipairs(candidates) do
        if U.valid(cand) then
            local n = displayName(cand) or U.fname(cand)
            M.noteSpell(cand, n)
            logFn(string.format("hook %s noted spell=%s", tag, tostring(n)))
            return
        end
    end
    -- Sometimes first arg is Context wrapper
    for _, cand in ipairs(candidates) do
        if cand ~= nil and type(cand) == "userdata" then
            local ok, inner = pcall(function() return cand.get and cand:get() or cand end)
            if ok and U.valid(inner) then
                M.noteSpell(inner, displayName(inner))
                logFn(string.format("hook %s noted via :get() %s", tag, tostring(displayName(inner))))
                return
            end
        end
    end
    logFn(string.format("hook %s fired (no UObject spell in args; types=%s/%s/%s)",
        tag, type(a), type(b), type(c)))
end

function M.installHooks(log)
    if hooksInstalled then return end
    hooksInstalled = true
    logFn = log or print

    local paths = {
        "/Script/Dominion.PlayerUtilityMagicComponent:HandleUtilitySpellCast",
        "/Script/Dominion.PlayerUtilityMagicComponent:Client_NotifySpellOnCooldown",
        "/Script/Dominion.PlayerCombatMagicComponent:HandleUtilitySpellCast",
        "/Script/Dominion.PlayerCombatMagicComponent:Client_NotifySpellOnCooldown",
    }
    for _, path in ipairs(paths) do
        local ok, err = pcall(function()
            RegisterHook(path, function(Context, A, B, C)
                local self = Context
                pcall(function()
                    if Context ~= nil and Context.get then self = Context:get() end
                end)
                noteFromHook(path:match("([^:]+)$") or path, A, B, C)
                -- Also note spell props on the component that fired.
                if U.valid(self) then
                    for _, prop in ipairs(SPELL_PROPS) do
                        local sp = tryProp(self, prop)
                        if U.valid(sp) then M.noteSpell(sp) end
                    end
                end
            end)
        end)
        logFn(string.format("RegisterHook %s => %s", path, ok and "ok" or tostring(err)))
    end
end

local function cooldownFor(comp, spell)
    if not U.valid(comp) or not U.valid(spell) then return nil end
    for _, meth in ipairs({ "GetCooldownTimeLeft", "GetCooldownTimeRemaining" }) do
        local rem = tryCall(comp, meth, spell)
        if type(rem) == "number" and rem > 0.05 and rem < 3600 then return rem end
    end
    -- Some builds expose remaining on the spell data itself.
    for _, n in ipairs(TIME_FIELDS) do
        local rem = tryCall(spell, n)
        if type(rem) == "number" and rem > 0.05 and rem < 3600 then return rem end
        rem = tryProp(spell, n)
        if type(rem) == "number" and rem > 0.05 and rem < 3600 then return rem end
    end
    -- TimeSinceCast + known duration is harder; try GetTimeSinceCast only as a signal.
    return nil
end

local function addCd(results, key, name, remaining)
    if type(remaining) ~= "number" or remaining <= 0.05 or remaining > 3600 then return end
    if not key or key == "" then key = name or "?" end
    if not name or name == "" then name = tostring(key) end
    local existing = results[key]
    if existing and existing.remaining >= remaining then return end
    results[key] = { key = key, name = name, remaining = remaining }
end

-- Walk a UE TArray-like (GetArrayNum / # / ForEach). Never pairs() userdata.
local function forEachArray(container, fn)
    if container == nil or type(container) == "number" or type(container) == "string" then return end
    if type(container) == "table" then
        for i, v in ipairs(container) do fn(i, v) end
        for k, v in pairs(container) do
            if type(k) ~= "number" then fn(k, v) end
        end
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
    if type(n) == "number" and n > 0 and n < 512 then
        for i = 1, n do
            local ok, entry = pcall(function() return container[i] end)
            if ok then fn(i, entry) end
        end
    end
end

local function discoverSpellsOnComp(comp)
    for _, prop in ipairs(SPELL_PROPS) do
        local sp = tryProp(comp, prop)
        if U.valid(sp) then M.noteSpell(sp) end
    end
    -- Replicated TMap often exposes parallel *_Key TArray.
    for _, keyField in ipairs({
        "LastCastTimeBySpellData_Key",
        "ActiveCooldowns_Key",
        "SpellCooldowns_Key",
        "Cooldowns_Key",
    }) do
        local keys = tryProp(comp, keyField)
        forEachArray(keys, function(_, spell)
            if U.valid(spell) then M.noteSpell(spell) end
        end)
    end
    for _, listName in ipairs({ "Spells", "UtilitySpells", "KnownSpells", "OurSpellActors" }) do
        forEachArray(tryProp(comp, listName), function(_, spell)
            if U.valid(spell) then M.noteSpell(spell) end
        end)
    end
end

--- Returns array of { key, name, remaining }, plus magic components found.
function M.activeCooldowns(pc)
    local pawn = U.playerPawn(pc)
    local comps = M.magicComponents(pc, pawn)
    local byKey = {}

    for _, comp in ipairs(comps) do
        pcall(function() discoverSpellsOnComp(comp) end)

        -- Component-level remaining (rare, but cheap).
        local remOnly = tryCall(comp, "GetCooldownTimeRemaining")
        if remOnly == nil then remOnly = tryProp(comp, "CooldownSecondsRemaining") end
        if type(remOnly) == "number" and remOnly > 0.05 and remOnly < 3600 then
            addCd(byKey, U.full(comp) .. ":self", "Spell", remOnly)
        end
    end

    -- Poll every tracked spell against every magic component.
    for key, info in pairs(tracked) do
        local spell = info.spell
        if U.valid(spell) then
            local best = nil
            for _, comp in ipairs(comps) do
                local rem = cooldownFor(comp, spell)
                if rem and (not best or rem > best) then best = rem end
            end
            if best then
                addCd(byKey, key, info.name, best)
            elseif (os.clock() - (info.notedAt or 0)) > 180 then
                tracked[key] = nil -- stale
            end
        else
            tracked[key] = nil
        end
    end

    local list = {}
    for _, row in pairs(byKey) do
        list[#list + 1] = row
    end
    table.sort(list, function(a, b)
        if a.remaining == b.remaining then
            return tostring(a.name) < tostring(b.name)
        end
        return a.remaining > b.remaining
    end)
    return list, comps
end

function M.dumpComponents(pc, log)
    log = log or print
    local pawn = U.playerPawn(pc)
    local comps = M.magicComponents(pc, pawn)
    log(string.format("magic components: %d trackedSpells=%d", #comps, (function()
        local n = 0
        for _ in pairs(tracked) do n = n + 1 end
        return n
    end)()))
    if U.valid(pawn) then
        for _, g in ipairs(GETTERS) do
            local v = tryCall(pawn, g)
            log(string.format("  pawn:%s() => %s", g, U.valid(v) and U.full(v) or tostring(v)))
        end
        for _, p in ipairs(PROPS) do
            local v = tryProp(pawn, p)
            log(string.format("  pawn.%s => %s", p, U.valid(v) and U.full(v) or tostring(v)))
        end
    end
    for i, comp in ipairs(comps) do
        log(string.format("  [%d] %s", i, U.full(comp)))
        for _, prop in ipairs(SPELL_PROPS) do
            local sp = tryProp(comp, prop)
            if U.valid(sp) then
                local rem = cooldownFor(comp, sp)
                log(string.format("    .%s = %s rem=%s", prop, displayName(sp) or U.fname(sp), tostring(rem)))
            end
        end
        for _, keyField in ipairs({ "LastCastTimeBySpellData_Key", "ActiveCooldowns_Key" }) do
            local keys = tryProp(comp, keyField)
            local count = 0
            forEachArray(keys, function(_, spell)
                count = count + 1
                if count <= 8 and U.valid(spell) then
                    local rem = cooldownFor(comp, spell)
                    log(string.format("    %s[%d] %s rem=%s", keyField, count, displayName(spell) or U.fname(spell), tostring(rem)))
                end
            end)
            log(string.format("    %s count~=%s type=%s", keyField, tostring(count), type(keys)))
        end
        -- Probe GetCooldownTimeLeft with no/odd args for signature hints.
        local r0 = tryCall(comp, "GetCooldownTimeLeft")
        local r1 = tryCall(comp, "GetCooldownTimeRemaining")
        log(string.format("    GetCooldownTimeLeft()=%s GetCooldownTimeRemaining()=%s", tostring(r0), tostring(r1)))
        for _, meth in ipairs({
            "GetCooldownTimeLeft", "GetCooldownTimeRemaining", "HandleUtilitySpellCast",
            "Client_NotifySpellOnCooldown", "GetTimeSinceCast", "IsBeingCast",
        }) do
            log(string.format("    :%s present=%s", meth, tostring(tryProp(comp, meth) ~= nil)))
        end
    end
end

return M
