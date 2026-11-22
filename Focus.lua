local ADDON, ns = ...
local L, Settings, Media, Rows, Items = ns.L, ns.Settings, ns.Media, ns.Rows, ns.Items
local S = Settings.Get

-- The selected quest tracker: a frame of its own with the focused quest
-- (super-tracked: Blizzard's map button, "Focus" in the menu), its title and
-- progress, placed anywhere. It draws the same quest row as the tracker,
-- from its own settings: every "focus<Name>" key is the tracker's "<name>"
-- for this frame (Settings.Prefixed). Its quest item button is a secure
-- button of its own on UIParent, placed at the row out of combat as the
-- tracker's (Items.lua): anchored to the frame it would pin it in combat.
local Focus = {}
ns.Focus = Focus

local cfg = Settings.Prefixed("focus")
Focus.cfg = cfg
local G = cfg.get

local ACCENT = { 0.31, 0.76, 0.97 }
local GRIP = 16

local frame, row, grip, outline, itemButton
local resizing

-- The quest whose objective moved last (QUEST_WATCH_UPDATE), for
-- followProgress. Only shown, never focused: C_SuperTrack in combat taints
-- the map pins (see Actions.Focus).
local progressed

-- The quest to show: the one that progressed last (if set), the focused
-- one, else (if set) the first tracked one.
function Focus.Quest()
    local id = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() or 0
    local headers = ns.Data.QuestHeaders()
    if progressed and G("followProgress") then
        local q = ns.Data.Quest(progressed, 0, headers, id)
        if q then return q end
        progressed = nil  -- left the log
    end
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

local function applyLook(top)
    Media.ApplyBackground(frame.bg, G("bgMode"), G("bgColor"), G("bgAlpha") / 100, G("bgTexture"))
    local radius = ns.Corners.Clamp(G("cornerRadius"), frame:GetWidth(), frame:GetHeight())
    ns.Corners.Fit(frame.clip, frame, radius, { frame.bg })
    local look = {
        style = G("borderStyle"), size = G("borderSize"), color = ns.Themes.Rim(G("borderColor")), radius = radius,
        edge = G("borderTexture"), edgeSize = G("borderEdgeSize"), bgExtend = G("bgExtend"),
        shadow = G("shadowEnabled"), shadowSize = G("shadowSize"), shadowAlpha = G("shadowAlpha") / 100,
    }
    local box = ns.Themes.ArtBox(frame)
    ns.Border.Draw(frame, box, look)
    ns.Themes.DrawArt(frame, box, look, top)
end

-- The grip sits at the bottom corner away from the anchor's side: that
-- edge moves, the anchored one stays. (A centred anchor is turned into a
-- corner when resizing starts.)
local function layoutUnlocked()
    local on = unlocked()
    for _, e in ipairs(outline) do e:SetShown(on) end
    grip:SetShown(on)
    local right = not G("point"):find("RIGHT")
    grip:ClearAllPoints()
    grip:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT", frame, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, 0)
    grip.icon:SetTexCoord(right and 0 or 1, right and 1 or 0, 0, 1)
end

-- The quest's item button at the row's top right, or hidden. Out of combat
-- only: in combat it stays as it was until PLAYER_REGEN_ENABLED lays out again.
local function placeItem(q, hasItem)
    if InCombatLockdown() then return end
    if not (hasItem and frame:IsShown()) then
        if itemButton then itemButton:Hide(); itemButton.logIndex, itemButton.link = nil, nil end
        return
    end
    itemButton = itemButton or Items.NewButton()
    Items.SetItem(itemButton, q.item)
    local es, us = row:GetEffectiveScale(), UIParent:GetEffectiveScale()
    local scale = frame:GetScale()
    itemButton:SetScale(scale)
    itemButton:ClearAllPoints()
    itemButton:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", row:GetRight() * es / us / scale, row:GetTop() * es / us / scale)
    itemButton:SetAlpha(frame:GetAlpha())
    itemButton:Show()
end

function Focus.Layout()
    if not frame then return end
    Focus.queued = false
    if not S("focusEnabled") or S("useBlizzard") then
        frame:Hide()
        placeItem()
        return
    end
    local q = Focus.Quest()
    -- Nothing focused: the frame is gone, locked or not.
    if not q then
        frame:Hide()
        placeItem()
        return
    end
    -- Inside a material frame (Goblin) the padding counts from its inner edge.
    local inset = ns.Themes.FrameInset(frame)
    local pad = G("padding") + inset
    local width = G("width")
    frame:SetWidth(width)
    -- A theme's banner (Goblin) behind the title, as the tracker's header:
    -- the title in the header's colour, past the banner's end, air below it.
    local banner, left, rowCfg = ns.Themes.Banner(), pad, cfg
    if banner then
        rowCfg = setmetatable({ onBanner = true, titleGap = pad + 4, text = function(name)
            local style = cfg.text(name)
            if name == "title" then style.color = ns.Themes.Accent(S("headerColor")) end
            return style
        end }, { __index = cfg })
        left = math.max(pad, ns.Themes.TitleIndent(G("titleSize") + 2 * pad))
    end
    local h, hasItem = Rows.LayoutQuest(row, q, width - pad - left, nil, rowCfg)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -pad)
    frame:SetHeight(h + 2 * pad)
    frame:Show()
    if G("hideInCombat") and InCombatLockdown() then frame:Hide() end
    place()
    -- The banner from the frame's inner edge, its middle on the title's.
    applyLook(banner and math.floor(row.title:GetStringHeight() + 2 * pad - inset + 0.5) or nil)
    layoutUnlocked()
    frame:SetAlpha(G("alpha") / 100)
    placeItem(q, hasItem)
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
    local w = resizing.w0 + (G("point"):find("RIGHT") and -dx or dx)
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
        -- Anchored at a corner first, so one edge stays where it is (from
        -- the centre the frame grew both ways and ran against the mouse).
        savePosition()
        place()
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
    createGrip()
    createOutline()
    Focus.frame = frame
    Focus.Layout()
end

ns.On("PLAYER_LOGIN", function() Focus.Build() end)

-- Fires just before the lockdown: the last moment to hide a secure button.
ns.On("PLAYER_REGEN_DISABLED", function()
    if itemButton and G("hideInCombat") then itemButton:Hide() end
end)

ns.On("QUEST_WATCH_UPDATE", function(_, questID)
    progressed = questID
    Focus.Refresh()
end)

for _, event in ipairs({ "SUPER_TRACKING_CHANGED", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
    "QUEST_TURNED_IN", "PLAYER_MONEY", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
    ns.On(event, function() Focus.Refresh() end)
end

Settings.OnChange(function(key)
    if not frame then return end
    if key == nil or key:find("^focus") then Focus.Refresh() end
end)
