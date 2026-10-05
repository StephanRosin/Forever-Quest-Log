local ADDON, ns = ...
local Settings, Media = ns.Settings, ns.Media
local S = Settings.Get

-- The quest list in the world map (QuestScrollFrame, Forever's quest log):
-- its background and the fonts of zone headers, quest titles and
-- objectives, like the tracker or set on their own. Blizzard's list stays
-- Blizzard's: its rows, clicks, colours (difficulty, completed, hover).
--
-- Rows come from three frame pools and are measured right after Acquire
-- (QuestLogQuests_AddQuestButton: SetText, then Text:GetHeight()). So the
-- font goes on in a hook on the pools' Acquire: before Blizzard measures,
-- and the heights fit. hooksecurefunc on a pool (a plain table, not a
-- frame) is safe in Forever; nothing of Blizzard's is written or called.
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

-- What a font string looked like before we touched it.
local function snapshot(fs)
    local file, size, flags = fs:GetFont()
    local sx, sy = fs:GetShadowOffset()
    local r, g, b, a = fs:GetShadowColor()
    return { object = fs:GetFontObject(), file = file, size = size, flags = flags or "",
             shadow = { sx or 0, sy or 0 }, shadowColor = { r or 0, g or 0, b or 0, a or 1 } }
end

-- Back to Blizzard's font. SetFontObject alone is not enough: after
-- SetFont the string still names the same font object, and setting that
-- one again changes nothing (in game the custom font stayed). So the
-- remembered font goes back explicitly.
local function restore(fs, o)
    if o.file then fs:SetFont(o.file, o.size, o.flags) end
    if o.object then fs:SetFontObject(o.object) end
    fs:SetShadowOffset(o.shadow[1], o.shadow[2])
    fs:SetShadowColor(o.shadowColor[1], o.shadowColor[2], o.shadowColor[3], o.shadowColor[4])
end

-- Font only (family, size, outline / shadow): the colour stays Blizzard's.
local function applyFont(fs, style)
    if not fs then return end
    if styled[fs] == version then return end
    styled[fs] = version
    if not style then
        if original[fs] then restore(fs, original[fs]) end
        return
    end
    if original[fs] == nil then original[fs] = snapshot(fs) end
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

local hooked = false
local function hookPools()
    local scroll = _G.QuestScrollFrame
    if hooked or not scroll then return end
    for key, fn in pairs(PARTS) do
        local pool = scroll[key]
        if pool and pool.Acquire then
            hooksecurefunc(pool, "Acquire", function(self) styleFrames(self, fn) end)
        end
    end
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
    local c, a = look.color, look.alpha
    if look.mode == "TEXTURE" then
        bg:SetTexture(Media.Path("background", look.texture), "REPEAT", "REPEAT")
        bg:SetHorizTile(true)
        bg:SetVertTile(true)
        bg:SetVertexColor(1, 1, 1, a)
    else
        bg:SetHorizTile(false)
        bg:SetVertTile(false)
        bg:SetColorTexture(1, 1, 1, 1)
        local top = CreateColor(c[1], c[2], c[3], a)
        local bottom = look.mode == "GRADIENT" and CreateColor(c[1], c[2], c[3], a * 0.35) or top
        bg:SetGradient("VERTICAL", bottom, top)
    end
    bg:Show()
end

-- All of it again (settings changed). Heights follow with Blizzard's next
-- update of the list (opening the map, any quest change).
function QuestLogStyle.Apply()
    local scroll = _G.QuestScrollFrame
    if not scroll then return end
    hookPools()
    version = version + 1
    for key, fn in pairs(PARTS) do
        if scroll[key] then styleFrames(scroll[key], fn) end
    end
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
