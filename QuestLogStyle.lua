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

-- Font only (family, size, outline / shadow): the colour stays Blizzard's.
local function applyFont(fs, style)
    if not fs then return end
    if styled[fs] == version then return end
    styled[fs] = version
    if original[fs] == nil then original[fs] = fs:GetFontObject() or false end
    if not style then
        if original[fs] then fs:SetFontObject(original[fs]) end
        return
    end
    local outline = (style.flag == "OUTLINE" or style.flag == "THICKOUTLINE") and style.flag or ""
    if not fs:SetFont(Media.FontPath(style.font), style.size, outline) then
        fs:SetFont(Media.DEFAULT.font, style.size, outline)
    end
    if style.flag == "SHADOW" then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    elseif original[fs] then
        local x, y = original[fs]:GetShadowOffset()
        fs:SetShadowOffset(x or 0, y or 0)
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

local function styleFrames(pool, fn, all)
    for f in pool:EnumerateActive() do fn(f) end
    if all and pool.inactiveObjects then
        for _, f in pairs(pool.inactiveObjects) do fn(f) end
    end
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
        if scroll[key] then styleFrames(scroll[key], fn, true) end
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
