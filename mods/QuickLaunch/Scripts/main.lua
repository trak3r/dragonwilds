-- Teflon Ted's Quick Launch — RuneScape: Dragonwilds (UE4SS)
-- Auto-advance the front-end into the last session. The game already defaults
-- the last character + world in those menus; we just press the primary CTAs.
-- Hold Escape to cancel. Stops once a world pawn exists or after max steps.

local TAG = "[TeflonTed.QuickLaunch] "
local VERSION = "1.0.0"
local STEP_DELAY = 0.75      -- seconds between clicks
local MAX_STEPS = 24
local BOOT_GRACE = 1.5       -- let UE4SS / boot widgets settle
local CANCEL_KEY = (Key and Key.ESCAPE) or nil

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

-- Prefer these widget-name fragments (own name / full path), highest first.
local PREFER = {
    "Button_Play",
    "Btn_Play",
    "PlayButton",
    "EnterWorld",
    "Button_EnterWorld",
    "Button_Confirm",
    "Btn_Confirm",
    "ConfirmButton",
    "ContinueButton",
    "Button_Continue",
    "PressAny",
    "PressToContinue",
    "SkipButton",
    "Button_Skip",
    "Button_OK",
    "Btn_OK",
}

local AVOID = {
    "Delete", "Quit", "Exit", "Settings", "Options", "CreateCharacter",
    "Create_World", "CreateWorld", "NewWorld", "NewGame", "Multiplayer",
    "Join", "ServerBrowser", "Dedicated", "Discord", "Credits", "BackButton",
    "Button_Back", "EditAppearance", "ImportPlayTest", "Hardcore",
    "Creative", "Cancel", "Decline", "Privacy", "Terms", "Newsletter",
}

local S = {
    started = os.clock(),
    cancelled = false,
    done = false,
    steps = 0,
    nextStepAt = 0,
    lastClick = "",
}

if CANCEL_KEY then
    pcall(RegisterKeyBind, CANCEL_KEY, function()
        if not S.done then
            S.cancelled = true
            log("cancelled (Escape) — take over the menus yourself")
        end
    end)
end

local function classOrName(w)
    local cls, name = "", ""
    pcall(function()
        local c = w:GetClass()
        if c then cls = c:GetFName():ToString() end
    end)
    name = U.fname(w)
    return cls, name, U.full(w)
end

local function isAvoid(full)
    for _, a in ipairs(AVOID) do
        if full:find(a, 1, true) then return true end
    end
    return false
end

local function preferScore(full)
    for i, p in ipairs(PREFER) do
        if full:find(p, 1, true) then
            return (#PREFER - i + 1) * 10
        end
    end
    return -1
end

local function isEnabledButton(w)
    if not U.valid(w) then return false end
    local okV, vis = pcall(function() return w:IsVisible() end)
    if okV and vis == false then return false end
    -- CommonUI / UMG enable checks (any success that says disabled → skip)
    local disabled = false
    pcall(function()
        if w.GetIsEnabled then
            if w:GetIsEnabled() == false then disabled = true end
        end
    end)
    pcall(function()
        if w.bIsEnabled == false then disabled = true end
    end)
    return not disabled
end

local function clickButton(w)
    if pcall(function() w:HandleButtonClicked() end) then return "HandleButtonClicked" end
    if pcall(function() w:Click() end) then return "Click" end
    if pcall(function() w:OnButtonBaseClicked() end) then return "OnButtonBaseClicked" end
    return nil
end

local function pickPrimaryButton()
    local best, bestScore, bestFull = nil, 0, ""
    local ok, all = pcall(FindAllOf, "CommonButtonBase")
    if not (ok and all) then
        ok, all = pcall(FindAllOf, "Button")
    end
    if not (ok and all) then return nil end

    for _, w in ipairs(all) do
        if isEnabledButton(w) then
            local _, _, full = classOrName(w)
            if full ~= "" and not full:find("Default__", 1, true) and not isAvoid(full) then
                local score = preferScore(full)
                if score > bestScore then
                    best, bestScore, bestFull = w, score, full
                end
            end
        end
    end
    return best, bestFull, bestScore
end

local function inWorldGameplay()
    local pc = U.localPC()
    if not pc then return false end
    local pawn = U.playerPawn(pc)
    return pawn ~= nil
end

local function stillInFrontEnd()
    -- Main-menu game mode / landing widgets still around.
    for _, cls in ipairs({ "BP_GameMode_MainMenu_C", "GameMode_MainMenu", "MainMenuUIAPI" }) do
        local ok, o = pcall(FindFirstOf, cls)
        if ok and U.valid(o) then return true end
    end
    local ok, all = pcall(FindAllOf, "GameModeBase")
    if ok and all then
        for _, gm in ipairs(all) do
            local n = U.full(gm)
            if n:find("MainMenu", 1, true) and not n:find("Default__", 1, true) then
                return true
            end
        end
    end
    return false
end

-- Optional native shortcut once a Persistence/Spud subsystem exists.
local function tryNativeLoad()
    for _, cls in ipairs({ "PersistenceSubsystem", "SpudSubsystem", "SpudGameInstanceSubsystem" }) do
        local ok, sub = pcall(FindFirstOf, cls)
        if ok and U.valid(sub) then
            if pcall(function() sub:LoadLatestSaveGame() end) then
                log("tried " .. cls .. ":LoadLatestSaveGame()")
                return true
            end
            if pcall(function() sub:QuickLoadGame() end) then
                log("tried " .. cls .. ":QuickLoadGame()")
                return true
            end
        end
    end
    return false
end

local nativeTried = false

local function step()
    if S.done or S.cancelled then return end
    if os.clock() < S.started + BOOT_GRACE then return end
    if os.clock() < S.nextStepAt then return end

    if inWorldGameplay() then
        S.done = true
        log("in world — Quick Launch finished after " .. tostring(S.steps) .. " step(s)")
        return
    end

    if S.steps >= MAX_STEPS then
        S.done = true
        log("gave up after " .. tostring(MAX_STEPS) .. " steps (still in front-end?)")
        return
    end

    -- After a few UI advances, try the native latest-save path once.
    if S.steps >= 2 and not nativeTried and stillInFrontEnd() then
        nativeTried = true
        tryNativeLoad()
        S.nextStepAt = os.clock() + STEP_DELAY
        return
    end

    local btn, full, score = pickPrimaryButton()
    if not btn then
        S.nextStepAt = os.clock() + STEP_DELAY
        return
    end

    local how = clickButton(btn)
    S.steps = S.steps + 1
    S.nextStepAt = os.clock() + STEP_DELAY
    if how then
        S.lastClick = full
        log(string.format("step %d: %s score=%d via %s", S.steps, full, score or 0, how))
    else
        log(string.format("step %d: found %s but click failed", S.steps, full))
    end
end

local okLoop = pcall(LoopInGameThreadWithDelay, 100, function()
    pcall(step)
end)
if not okLoop then
    local queued = false
    LoopAsync(100, function()
        if queued then return false end
        queued = true
        local sent = pcall(ExecuteInGameThread, function()
            queued = false
            pcall(step)
        end)
        if not sent then queued = false end
        return false
    end)
end

log("loaded v" .. VERSION .. " — auto-advancing front-end (Esc cancels)")
