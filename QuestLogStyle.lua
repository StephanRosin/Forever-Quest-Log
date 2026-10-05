local ADDON, ns = ...
local Settings, Media = ns.Settings, ns.Media
local S = Settings.Get

-- The quest list in the world map (QuestScrollFrame, Forever's quest log):
-- its background and the fonts of zone headers, quest titles and
-- objectives, like the tracker or set on their own. Blizzard's list stays
-- Blizzard's: its rows, clicks, colours (difficulty, completed, hover).
--
-- Rows come from three frame pools and are measured right after Acquire.
-- The pools are SECURE pools in Forever (CreateFramePool =
-- CreateSecureFramePool): a hooksecurefunc on their Acquire made it nil
-- for Blizzard's own call ("attempt to call a nil value",
-- QuestMapFrame.lua:2045) and tainted the list. So nothing hooks the
-- pools. The font goes on after Blizzard's update instead, in a hook on the
-- global function QuestLogQuests_Update (safe); the rows keep that font, so
-- from the next update on (any quest change, opening the map) Blizzard
-- measures them with it. A row styled for the very first time can be
-- measured once with Blizzard's font.
local QuestLogStyle = {}
ns.QuestLogStyle = QuestLogStyle

-- The styles in use for "header", "title", "objective", or nil (Blizzard's).
function QuestLogStyle.TextStyle(part)
    local mode = S("logStyle")
    if mode == "BLIZZARD" then return nil end
    if mode == "TRACKER" then
        local name = ({ header = "zone", title = "title", objective = "objective" })[part]
        return Settings.TextStyle(name)
    end
    local p = "log" .. part:sub(1, 1):upper() .. part:sub(2)
    return { font = S(p .. "Font"), size = S(p .. "Size"), flag = S(p .. "Flag") }
end

-- The background in use: { mode, color, alpha, texture } or nil.
function QuestLogStyle.Background()
    local mode = S("logStyle")
    if mode == "BLIZZARD" then return nil end
    if mode == "TRACKER" then
        return { mode = S("bgMode"), color = S("bgColor"), alpha = S("bgAlpha") / 100, texture = S("bgTexture") }
    end
    return { mode = S("logBgMode"), color = S("logBgColor"), alpha = S("logBgAlpha") / 100, texture = S("logBgTexture") }
end

-- Fonts ------------------------------------------------------------------

-- Blizzard's font object per font string, to give it back; and which
-- version of our settings a string carries.
local original = setmetatable({}, { __mode = "k" })
local styled = setmetatable({}, { __mode = "k" })
local version = 1

-- Font only (family, size, outline / shadow): the colour stays Blizzard's.
local function applyFont(fs, style)
    if not fs then return end
    if styled[fs] == version then return end
    styled[fs] = version
    if not style then
        if original[fs] then Media.Restore(fs, original[fs]) end
        return
    end
    if original[fs] == nil then original[fs] = Media.Snapshot(fs) end
    local outline = (style.flag == "OUTLINE" or style.flag == "THICKOUTLINE") and style.flag or ""
    if not fs:SetFont(Media.FontPath(style.font), style.size, outline) then
        fs:SetFont(Media.DEFAULT.font, style.size, outline)
    end
    if style.flag == "SHADOW" then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        local o = original[fs]
        fs:SetShadowOffset(o.shadow[1], o.shadow[2])
        fs:SetShadowColor(o.shadowColor[1], o.shadowColor[2], o.shadowColor[3], o.shadowColor[4])
    end
end

local function headerText(button)
    return button.ButtonText or (button.GetFontString and button:GetFontString())
end

local PARTS = {
    titleFramePool = function(f) applyFont(f.Text, QuestLogStyle.TextStyle("title")) end,
    objectiveFramePool = function(f)
        local style = QuestLogStyle.TextStyle("objective")
        applyFont(f.Text, style)
        applyFont(f.Dash, style)
    end,
    headerFramePool = function(f) applyFont(headerText(f), QuestLogStyle.TextStyle("header")) end,
}

-- The rows on screen. Free rows (in Forever a secure stack, not a plain
-- list) get the current font when Blizzard acquires them again.
local function styleFrames(pool, fn)
    for f in pool:EnumerateActive() do fn(f) end
end

local function styleAll()
    local scroll = _G.QuestScrollFrame
    if not scroll then return end
    for key, fn in pairs(PARTS) do
        if scroll[key] then styleFrames(scroll[key], fn) end
    end
end

local hooked = false
local function hookUpdate()
    if hooked or type(_G.QuestLogQuests_Update) ~= "function" then return end
    hooksecurefunc("QuestLogQuests_Update", styleAll)
    hooked = true
end

-- Background -------------------------------------------------------------

local bg

local function applyBackground()
    local scroll = _G.QuestScrollFrame
    if not scroll then return end
    local blizzard = scroll.Background
    local look = QuestLogStyle.Background()
    if blizzard then blizzard:SetAlpha(look and 0 or 1) end
    if not look then
        if bg then bg:Hide() end
        return
    end
    if not bg then
        bg = scroll:CreateTexture(nil, "BACKGROUND", nil, 1)
        if blizzard then
            bg:SetAllPoints(blizzard)
        else
            bg:SetAllPoints(scroll)
        end
    end
    Media.ApplyBackground(bg, look.mode, look.color, look.alpha, look.texture)
    bg:Show()
end

-- All of it again (settings changed). Heights follow with Blizzard's next
-- update of the list (opening the map, any quest change).
function QuestLogStyle.Apply()
    local scroll = _G.QuestScrollFrame
    if not scroll then return end
    hookUpdate()
    version = version + 1
    styleAll()
    applyBackground()
end

ns.On("PLAYER_LOGIN", function() QuestLogStyle.Apply() end)

Settings.OnChange(function(key)
    if not hooked then return end
    if key == nil or key:find("^log") or key:find("^bg") or key:find("Font$") or key:find("Size$")
        or key:find("Flag$") then
        QuestLogStyle.Apply()
    end
end)
