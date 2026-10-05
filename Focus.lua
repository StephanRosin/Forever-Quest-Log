local ADDON, ns = ...
local L, Settings, Media, Rows = ns.L, ns.Settings, ns.Media, ns.Rows
local S = Settings.Get

-- The selected quest tracker: a frame of its own with the focused quest
-- (super-tracked: Blizzard's map button, "Focus" in the menu), its title and
-- progress, placed anywhere. It draws the same quest row as the tracker,
-- from its own settings: every "focus<Name>" key is the tracker's "<name>"
-- for this frame (Settings.Prefixed). No item buttons here (secure buttons
-- would pin the frame in combat); the tracker keeps them.
local Focus = {}
ns.Focus = Focus

local cfg = Settings.Prefixed("focus")
Focus.cfg = cfg
local G = cfg.get

local ACCENT = { 0.31, 0.76, 0.97 }
local GRIP = 16

local frame, row, empty, grip, outline
local resizing

-- The quest to show: the focused one, else (if set) the first tracked one.
function Focus.Quest()
    local id = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() or 0
    local headers = ns.Data.QuestHeaders()
    if id and id > 0 then
        local q = ns.Data.Quest(id, 0, headers, id)
        if q then return q end
    end
    if G("fallback") == "FIRST" then
        local quests = ns.Data.Quests()
        return quests[1]
    end
    return nil
end

local function unlocked() return not G("locked") end

-- Placement (as the tracker: the nearest corner, offsets in UIParent units)
local function place()
    if frame.moving then return end
    local s = G("scale") / 100
    frame:SetScale(s)
    frame:ClearAllPoints()
    frame:SetPoint(G("point"), UIParent, G("point"), G("x") / s, G("y") / s)
end

local function savePosition()
    local s = frame:GetScale()
    local left, right = frame:GetLeft() * s, frame:GetRight() * s
    local top, bottom = frame:GetTop() * s, frame:GetBottom() * s
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local h = ((left + right) / 2 < sw / 2) and "LEFT" or "RIGHT"
    local v = ((top + bottom) / 2 < sh / 2) and "BOTTOM" or "TOP"
    local x = (h == "LEFT") and left or (right - sw)
    local y = (v == "TOP") and (top - sh) or bottom
    Settings.SetMany({ [cfg.key("point")] = v .. h, [cfg.key("x")] = math.floor(x + 0.5),
        [cfg.key("y")] = math.floor(y + 0.5) })
end

local function applyLook()
    Media.ApplyBackground(frame.bg, G("bgMode"), G("bgColor"), G("bgAlpha") / 100, G("bgTexture"))
    local radius = ns.Corners.Clamp(G("cornerRadius"), frame:GetWidth(), frame:GetHeight())
    ns.Corners.Fit(frame.clip, frame, radius, { frame.bg })
    ns.Border.Draw(frame, frame, {
        style = G("borderStyle"), size = G("borderSize"), color = G("borderColor"), radius = radius,
        shadow = G("shadowEnabled"), shadowSize = G("shadowSize"), shadowAlpha = G("shadowAlpha") / 100,
    })
end

local function layoutUnlocked()
    local on = unlocked()
    for _, e in ipairs(outline) do e:SetShown(on) end
    grip:SetShown(on)
end

function Focus.Layout()
    if not frame then return end
    Focus.queued = false
    if not S("focusEnabled") or S("useBlizzard") then
        frame:Hide()
        return
    end
    local q = Focus.Quest()
    local pad = G("padding")
    local width = G("width")
    frame:SetWidth(width)
    local h
    if q then
        row:Show()
        empty:Hide()
        h = Rows.LayoutQuest(row, q, width - 2 * pad, nil, cfg)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
    else
        row:Hide()
        empty:SetShown(unlocked())
        Media.ApplyText(empty, cfg.text("objective"))
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
        empty:SetWidth(width - 2 * pad)
        empty:SetJustifyH("LEFT")
        h = math.max(16, empty:GetStringHeight())
    end
    frame:SetHeight(h + 2 * pad)
    -- Nothing focused and locked: out of the way.
    frame:SetShown(q ~= nil or unlocked())
    if G("hideInCombat") and InCombatLockdown() then frame:Hide() end
    place()
    applyLook()
    layoutUnlocked()
    frame:SetAlpha(G("alpha") / 100)
end

function Focus.Refresh()
    if not frame or Focus.queued then return end
    Focus.queued = true
    C_Timer.After(0, Focus.Layout)
end

-- Resizing: the width only (the height follows the quest).
local function cursorX()
    local x = GetCursorPosition()
    return x / UIParent:GetEffectiveScale()
end

local function onResize()
    if not resizing then return end
    local dx = (cursorX() - resizing.x0) / frame:GetScale()
    local w = resizing.w0 + (G("point"):find("LEFT") and dx or -dx)
    local range = Settings.RANGES[cfg.key("width")]
    w = math.max(range[1], math.min(range[2], math.floor(w + 0.5)))
    if w ~= resizing.w then
        resizing.w = w
        ns.DB()[cfg.key("width")] = w
        Focus.Layout()
    end
end

local function createGrip()
    grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP, GRIP)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip.icon = grip:CreateTexture(nil, "OVERLAY")
    grip.icon:SetAllPoints()
    grip.icon:SetTexture(Media.Icon("Resize"))
    grip.icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
    grip:SetScript("OnMouseDown", function()
        resizing = { w0 = G("width"), x0 = cursorX() }
        grip:SetScript("OnUpdate", onResize)
    end)
    grip:SetScript("OnMouseUp", function()
        grip:SetScript("OnUpdate", nil)
        if not resizing then return end
        local w = resizing.w or G("width")
        resizing = nil
        Settings.Set(cfg.key("width"), w)
    end)
end

local function createOutline()
    outline = {}
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
        outline[i] = t
    end
    local o = 5
    outline[1]:SetPoint("TOPLEFT", -o, o); outline[1]:SetPoint("TOPRIGHT", o, o); outline[1]:SetHeight(1)
    outline[2]:SetPoint("BOTTOMLEFT", -o, -o); outline[2]:SetPoint("BOTTOMRIGHT", o, -o); outline[2]:SetHeight(1)
    outline[3]:SetPoint("TOPLEFT", -o, o); outline[3]:SetPoint("BOTTOMLEFT", -o, -o); outline[3]:SetWidth(1)
    outline[4]:SetPoint("TOPRIGHT", o, o); outline[4]:SetPoint("BOTTOMRIGHT", o, -o); outline[4]:SetWidth(1)
end

function Focus.Build()
    if frame or S("useBlizzard") then return end
    frame = CreateFrame("Frame", "ForeverQuestLogFocus", UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    frame:EnableMouse(true)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.clip = {}
    row = Rows.NewQuestRow(frame)
    -- Dragging the frame (unlocked, or Ctrl) wherever the quest row does not
    -- take the click: the row passes a left-button drag up to the frame.
    local function startMove(_, button)
        if button == "LeftButton" and (unlocked() or IsControlKeyDown()) then
            frame:StartMoving()
            frame.moving = true
        end
    end
    local function stopMove()
        if not frame.moving then return end
        -- A button clicks after OnMouseUp: a drag must not open the quest.
        row.suppressClick = true
        frame:StopMovingOrSizing()
        frame.moving = nil
        savePosition()
    end
    frame:SetScript("OnMouseDown", startMove)
    frame:SetScript("OnMouseUp", stopMove)
    row:HookScript("OnMouseDown", startMove)
    row:HookScript("OnMouseUp", stopMove)
    empty = frame:CreateFontString(nil, "OVERLAY")
    empty:SetPoint("TOPLEFT", 8, -8)
    -- A font string without a template has no font: set one before any text.
    Media.ApplyText(empty, cfg.text("objective"))
    empty:SetText(L.FOCUS_EMPTY)
    createGrip()
    grip:SetPoint("BOTTOMRIGHT")
    createOutline()
    Focus.frame = frame
    Focus.Layout()
end

ns.On("PLAYER_LOGIN", function() Focus.Build() end)

for _, event in ipairs({ "SUPER_TRACKING_CHANGED", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
    "QUEST_TURNED_IN", "PLAYER_MONEY", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
    ns.On(event, function() Focus.Refresh() end)
end

Settings.OnChange(function(key)
    if not frame then return end
    if key == nil or key:find("^focus") then Focus.Refresh() end
end)
