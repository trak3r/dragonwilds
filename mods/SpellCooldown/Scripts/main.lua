-- Teflon Ted's Spell Cooldown — RuneScape: Dragonwilds (UE4SS)
-- Toast on the main HUD: name + seconds left for spells currently on cooldown.
-- No hotkeys, no config. Thin alternative to full spell bars / wheels.

local TAG = "[TeflonTed.SpellCooldown] "
local VERSION = "1.0.2"
local POLL_MS = 200
local MAX_TOASTS = 6
local HUD_Z = 200
local FONT_SIZE = 22
-- Top-right: clear of compass (top-center) and XP popup. No config file.
local HUD_X = -36
local HUD_Y = 160

local Visibility_HIDDEN = 2
local Visibility_SELF_HIT_TEST_INVISIBLE = 4

local function setupPath()
    local src = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
    local dir = src:match("^(.*)[/\\]")
    if dir then
        package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path
    end
end
setupPath()

local U = require("teflonted.util")
local Spells = require("teflonted.spells")

local function log(msg)
    print(TAG .. tostring(msg) .. "\n")
end

local S = {
    world = nil,
    readyAt = nil,
    dumped = false,
    dumpAt = nil,
    hud = nil,
    border = nil,
    vbox = nil,
    rows = {}, -- TextBlock widgets
    slot = nil,
    umgOk = nil, -- nil unknown, true/false
    lastErrAt = 0,
    lastCdLogAt = 0,
}

local function worldKey(pc)
    local w = nil
    pcall(function() w = pc:GetWorld() end)
    if U.valid(w) then return U.full(w) end
    return "?"
end

local function teardownHud()
    if U.valid(S.border) then pcall(function() S.border:RemoveFromParent() end) end
    if U.valid(S.hud) then
        pcall(function() S.hud:RemoveFromParent() end)
        pcall(function() S.hud:RemoveFromViewport() end)
    end
    S.hud, S.border, S.vbox, S.slot, S.rows = nil, nil, nil, nil, {}
end

local function setText(widget, text)
    if not U.valid(widget) then return end
    pcall(function() widget:SetText(FText(tostring(text))) end)
end

local function ensureHud()
    if S.umgOk == false then return false end
    if U.valid(S.border) and U.valid(S.vbox) then return true end

    local UEHelpers = nil
    pcall(function() UEHelpers = require("UEHelpers") end)
    local gi = nil
    if UEHelpers then pcall(function() gi = UEHelpers.GetGameInstance() end) end
    if not U.valid(gi) then
        S.umgOk = false
        return false
    end

    local user_widget_cls = StaticFindObject("/Script/UMG.UserWidget")
    local widget_tree_cls = StaticFindObject("/Script/UMG.WidgetTree")
    local canvas_cls = StaticFindObject("/Script/UMG.CanvasPanel")
    local border_cls = StaticFindObject("/Script/UMG.Border")
    local text_cls = StaticFindObject("/Script/UMG.TextBlock")
    local vbox_cls = StaticFindObject("/Script/UMG.VerticalBox")
    if not (user_widget_cls and widget_tree_cls and canvas_cls and border_cls and text_cls and vbox_cls) then
        log("UMG classes missing — toast HUD disabled")
        S.umgOk = false
        return false
    end

    local okBuild, err = pcall(function()
        local hud = StaticConstructObject(user_widget_cls, gi, FName("TeflonTedSpellCooldownHUD"))
        hud.WidgetTree = StaticConstructObject(widget_tree_cls, hud, FName("TeflonTedSpellCooldownTree"))
        local canvas = StaticConstructObject(canvas_cls, hud.WidgetTree, FName("TeflonTedSpellCooldownCanvas"))
        hud.WidgetTree.RootWidget = canvas

        local border = StaticConstructObject(border_cls, canvas, FName("TeflonTedSpellCooldownBorder"))
        border:SetBrushColor({ R = 0.0, G = 0.0, B = 0.0, A = 0.75 })
        border:SetPadding({ Left = 14, Top = 8, Right = 14, Bottom = 8 })

        local vbox = StaticConstructObject(vbox_cls, border, FName("TeflonTedSpellCooldownVBox"))
        border:SetContent(vbox)

        local rows = {}
        for i = 1, MAX_TOASTS do
            local tb = StaticConstructObject(text_cls, vbox, FName("TeflonTedSpellCooldownRow" .. i))
            pcall(function() tb.Font.Size = FONT_SIZE end)
            pcall(function()
                tb:SetColorAndOpacity({
                    SpecifiedColor = { R = 0.95, G = 0.92, B = 0.75, A = 1.0 },
                    ColorUseRule = 0,
                })
            end)
            vbox:AddChildToVerticalBox(tb)
            tb.Visibility = Visibility_HIDDEN
            rows[i] = tb
        end

        local slot = canvas:AddChildToCanvas(border)
        slot:SetAutoSize(true)
        -- Anchor top-right so compass / XP at top-center don't cover it.
        slot:SetAnchors({ Minimum = { X = 1.0, Y = 0.0 }, Maximum = { X = 1.0, Y = 0.0 } })
        slot:SetAlignment({ X = 1.0, Y = 0.0 })
        slot:SetPosition({ X = HUD_X, Y = HUD_Y })

        canvas.Visibility = Visibility_SELF_HIT_TEST_INVISIBLE
        border.Visibility = Visibility_HIDDEN
        hud:AddToViewport(HUD_Z)

        S.hud = hud
        S.border = border
        S.vbox = vbox
        S.rows = rows
        S.slot = slot
    end)

    if not okBuild then
        log("HUD build failed: " .. tostring(err))
        teardownHud()
        S.umgOk = false
        return false
    end

    S.umgOk = true
    log("HUD ready (top-right)")
    return true
end

local function formatRemaining(sec)
    if sec >= 60 then
        local m = math.floor(sec / 60)
        local s = math.floor(sec % 60 + 0.5)
        return string.format("%dm %02ds", m, s)
    end
    if sec >= 10 then
        return string.format("%ds", math.floor(sec + 0.5))
    end
    return string.format("%.1fs", sec)
end

local function updateHud(cds)
    if not ensureHud() then return end
    local n = math.min(#cds, MAX_TOASTS)
    if n == 0 then
        pcall(function() S.border.Visibility = Visibility_HIDDEN end)
        for i = 1, MAX_TOASTS do
            if U.valid(S.rows[i]) then
                S.rows[i].Visibility = Visibility_HIDDEN
            end
        end
        return
    end
    pcall(function() S.border.Visibility = Visibility_SELF_HIT_TEST_INVISIBLE end)
    for i = 1, MAX_TOASTS do
        local row = S.rows[i]
        if U.valid(row) then
            if i <= n then
                local cd = cds[i]
                setText(row, string.format("%s  %s", cd.name, formatRemaining(cd.remaining)))
                row.Visibility = Visibility_SELF_HIT_TEST_INVISIBLE
            else
                row.Visibility = Visibility_HIDDEN
            end
        end
    end
end

local function tick()
    local pc = U.localPC()
    if not pc then
        if U.valid(S.border) then teardownHud() end
        return
    end

    local wkey = worldKey(pc)
    if wkey ~= S.world then
        S.world = wkey
        S.readyAt = os.clock() + 3
        S.dumped = false
        S.dumpAt = os.clock() + 8
        teardownHud()
        S.umgOk = nil
    end
    if S.readyAt and os.clock() < S.readyAt then return end

    local cds, comps = Spells.activeCooldowns(pc)
    updateHud(cds)

    if #cds > 0 and (os.clock() - (S.lastCdLogAt or 0)) > 5 then
        S.lastCdLogAt = os.clock()
        log(string.format("showing %d cooldown(s); top=%s %.1fs",
            #cds, tostring(cds[1].name), cds[1].remaining))
    end

    if not S.dumped and S.dumpAt and os.clock() >= S.dumpAt then
        S.dumped = true
        if #cds > 0 then
            log(string.format("ok — tracking %d cooldown(s) via %d magic component(s)", #cds, #comps))
        else
            log("discovery dump (no active CDs yet — cast a spell, watch for hook/noted lines)")
            Spells.dumpComponents(pc, log)
        end
    end
end

Spells.installHooks(log)

local okLoop = pcall(LoopInGameThreadWithDelay, POLL_MS, function()
    local ok, err = pcall(tick)
    if not ok then
        local now = os.clock()
        if now - (S.lastErrAt or 0) > 2 then
            S.lastErrAt = now
            log("tick error: " .. tostring(err))
        end
    end
end)
if not okLoop then
    local queued = false
    LoopAsync(POLL_MS, function()
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

log(string.format(
    "loaded v%s — HUD notice top-right for active spell cooldowns (max %d); poll %dms",
    VERSION, MAX_TOASTS, POLL_MS
))
