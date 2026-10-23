-- Teflon Ted's God Mode — bare bones, ALWAYS ON, zero poll loop.
-- Apply once when the local pawn is ready. Idle afterward.
-- Signatures from KithMyTrainer 1.3.2 (Nexus #684).

local TAG = "[TeflonTed.GodMode] "
local VERSION = "0.1.0-bare"

local function setupPath()
    local src = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
    local dir = src:match("^(.*)[/\\]")
    if dir then
        package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path
    end
end
setupPath()

local U = require("teflonted.util")

local function log(msg)
    print(TAG .. tostring(msg) .. "\n")
end

local appliedFor = nil

local function healthComp(pawn)
    local hc = nil
    pcall(function() hc = pawn:GetBaseHealthComponent() end)
    if U.valid(hc) then return hc end
    pcall(function() hc = pawn.BP_Components_Health end)
    return U.valid(hc) and hc or nil
end

local function damageComp(pawn)
    local dc = nil
    pcall(function() dc = pawn:GetPlayerDamageComponent() end)
    if U.valid(dc) then return dc end
    pcall(function() dc = pawn.BP_Components_PlayerDamage end)
    if U.valid(dc) then return dc end
    pcall(function() dc = pawn.PlayerDamageComponent end)
    return U.valid(dc) and dc or nil
end

local function applyOnce()
    local pc = U.localPC()
    if not pc or not U.isHost(pc) then return false end
    local pawn = U.playerPawn(pc)
    if not pawn then return false end

    local key = U.full(pawn)
    if key == "" or key == appliedFor then return true end

    local health = healthComp(pawn)
    local damage = damageComp(pawn)
    if not (U.valid(health) and U.valid(damage)) then
        log("comps not ready yet")
        return false
    end

    local ok, err = pcall(function()
        damage:SetCanTakeDamage(false)
        damage:SetIsInvulnerable(true, damage)
        health:SetIsImmortal(true, health)
        health:SetHealth(health:GetMaxHealth(), "TeflonTedGodMode")
    end)
    if not ok then
        log("apply failed: " .. tostring(err))
        return false
    end

    appliedFor = key
    log("ON (one-shot) — idle, no poll. Disable GodMode in mods.txt to turn off.")
    return true
end

local function schedule(delayMs, attemptsLeft)
    attemptsLeft = attemptsLeft or 6
    pcall(ExecuteWithDelay, delayMs, function()
        pcall(ExecuteInGameThread, function()
            if applyOnce() then return end
            if attemptsLeft > 1 then
                schedule(2000, attemptsLeft - 1)
            else
                log("gave up waiting for player comps")
            end
        end)
    end)
end

-- Re-apply only when controller restarts onto a new pawn (load / respawn).
pcall(function()
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        appliedFor = nil
        schedule(2000, 6)
    end)
end)

schedule(3000, 6)

log("loaded v" .. VERSION .. " — always on, apply-once, no tick loop")
