-- UNDER DEVELOPMENT — DO NOT USE (soft-locks input). Not deployed by Deploy-Mods.ps1.
-- Teflon Ted's Un-Interact — RuneScape: Dragonwilds (UE4SS)
-- Press E again while an interaction UI is open to dismiss it (Escape-equivalent).
--
-- Lessons from 1.0.0–1.0.2:
--   * Mass-DeactivateWidget soft-locks (HUD widgets stay "activated").
--   * BP_OnHandleBackAction is a Blueprint stub — no-ops from Lua.
--   * Scoring GetFullName() is wrong: children inherit "MainPanel" from their outer path,
--     so we nibbled InventoryInputs / EquipmentBar / slots instead of the real root.
--   * Close ONLY widgets whose OWN class name contains MainPanel.
--   * One E may need to close several MainPanels (chest host + player inventory).
--   * Cursor-on = CommonUI menu mode; after roots deactivate, restore game input if needed.
--   * Some panels bind Q/E to tabs — E-to-close intentionally wins while the UI is open.

local TAG = "[TeflonTed.UnInteract] "
local VERSION = "1.0.3"
local OPEN_GRACE = 0.28
local KEY = (Key and Key.E) or nil

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

local S = {
    pending = false,
    uiSince = nil,
    wasUi = false,
}

local function pauseMenuOpen()
    for _, cls in ipairs({ "PauseMenuScreen", "WBP_PauseMenuScreen_C" }) do
        local ok, pm = pcall(FindFirstOf, cls)
        if ok and U.valid(pm) then
            local okA, act = pcall(function() return pm:IsActivated() end)
            if okA and act == true then return true end
        end
    end
    return false
end

local function uiOpen(pc)
    if not U.valid(pc) then return false end
    local cur = nil
    pcall(function() cur = pc.bShowMouseCursor end)
    return cur == true
end

local function isActivated(w)
    local ok, act = pcall(function() return w:IsActivated() end)
    return ok and act == true
end

local function className(w)
    local n = ""
    pcall(function()
        local c = w:GetClass()
        if c then n = c:GetFName():ToString() end
    end)
    if n == "" then n = U.fname(w) end
    return n
end

-- Own class must be a MainPanel root (not a child whose path merely contains MainPanel).
local function isMainPanelRoot(w)
    local cls = className(w)
    if cls == "" then return false, cls end
    if not cls:find("MainPanel", 1, true) then return false, cls end
    if cls:find("Pause", 1, true) then return false, cls end
    return true, cls
end

local function restoreGameInput(pc)
    local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    if U.valid(wbl) and U.valid(pc) then
        pcall(function() wbl:SetInputMode_GameOnly(pc, false) end)
    end
    pcall(function() pc.bShowMouseCursor = false end)
end

-- Deactivate every activated *MainPanel* root. One Esc usually tears the whole stack down;
-- chest UIs often keep both WorldActorInventory_MainPanel and Inventory_MainPanel active.
local function closeMainPanels()
    local closed = {}
    local ok, all = pcall(FindAllOf, "CommonActivatableWidget")
    if not (ok and all) then return closed end

    for _, w in ipairs(all) do
        if U.valid(w) and isActivated(w) then
            local isRoot, cls = isMainPanelRoot(w)
            if isRoot then
                pcall(function() w:DeactivateWidget() end)
                if not isActivated(w) then
                    closed[#closed + 1] = cls
                end
            end
        end
    end
    return closed
end

local function uninteract()
    local pc = U.localPC()
    if not pc then return end
    if not uiOpen(pc) then return end
    if pauseMenuOpen() then return end
    if not S.uiSince or (os.clock() - S.uiSince) < OPEN_GRACE then
        return
    end

    local closed = closeMainPanels()
    if #closed == 0 then
        log("E while UI open, but no activated MainPanel root found")
        return
    end

    -- Roots are gone; if CommonUI did not clear menu mode, finish the job.
    if uiOpen(pc) then
        restoreGameInput(pc)
        log("closed " .. table.concat(closed, ", ") .. " + restored game input")
    else
        log("closed " .. table.concat(closed, ", "))
    end
end

local function onKey()
    S.pending = true
end

if KEY then
    local ok = pcall(RegisterKeyBind, KEY, function()
        pcall(ExecuteInGameThread, onKey)
    end)
    if ok then
        log("bound Un-Interact to E")
    else
        log("could not bind Key.E")
    end
else
    log("Key.E unavailable")
end

local function tick()
    if S.pending then
        S.pending = false
        local ok, err = pcall(uninteract)
        if not ok then log("error: " .. tostring(err)) end
    end

    local pc = U.localPC()
    local open = pc and uiOpen(pc) or false
    if open and not S.wasUi then
        S.uiSince = os.clock()
    elseif not open then
        S.uiSince = nil
    end
    S.wasUi = open
end

local okLoop = pcall(LoopInGameThreadWithDelay, 50, function()
    pcall(tick)
end)
if not okLoop then
    local queued = false
    LoopAsync(50, function()
        if queued then return false end
        queued = true
        local sent = pcall(ExecuteInGameThread, function()
            queued = false
            pcall(tick)
        end)
        if not sent then queued = false end
        return false
    end)
end

log("loaded v" .. VERSION .. " — press E again to leave interactions")
