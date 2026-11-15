local ADDON, ns = ...

-- Fonts, background textures and bar textures: the game's own, plus every
-- one another addon registers with LibSharedMedia (the library itself is
-- not shipped).
local Media = {}
ns.Media = Media

local MEDIA = "Interface\\AddOns\\ForeverQuestLog\\Media\\"
function Media.Icon(name) return MEDIA .. "Icon" .. name .. ".tga" end

Media.BLIZZARD = {
    font = {
        { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
        { name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
        { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
    },
    background = {
        { name = "Blizzard Dialog Background Dark", path = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
        { name = "Blizzard Dialog Background", path = "Interface\\DialogFrame\\UI-DialogBox-Background" },
        { name = "Blizzard Dialog Background Gold", path = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background" },
        { name = "Blizzard Tooltip", path = "Interface\\Tooltips\\UI-Tooltip-Background" },
        { name = "Blizzard Parchment", path = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal" },
        { name = "Blizzard Rock", path = "Interface\\FrameGeneral\\UI-Background-Rock" },
        { name = "Blizzard Marble", path = "Interface\\FrameGeneral\\UI-Background-Marble" },
    },
    statusbar = {
        { name = "Solid", path = "Interface\\Buttons\\WHITE8X8" },
        { name = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
        { name = "Blizzard Raid Bar", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    },
}
-- The themes' fonts, backdrops and bar textures come with the embedded
-- LibForeverThemes (its fonts under the SIL Open Font License, see its
-- Media/Fonts), which also loads the fonts early. Built at use: a newer
-- copy of the library loading after us brings the paths. The backdrops are
-- settings here (bgTexture "FQL <name>"); tint darkens a light backdrop so
-- the light text on it stays readable.
local Lib = LibForeverThemes
local THEME_ART = {
    { "Wood", 0.5 }, { "Tech", 1 }, { "Parchment", 0.45 }, { "Stone", 0.55 }, { "Glass", 1 }, { "Comic", 0.7 },
    { "Frost", 0.55 }, { "Pixel", 1 }, { "Swiss", 1 }, { "Console", 1 }, { "Pitwall", 1 },
}
local OWN = {
    font = function() return Lib.FONTS end,
    background = function()
        local list = {}
        for i, a in ipairs(THEME_ART) do
            list[i] = { name = "FQL " .. a[1], path = Lib.Texture(a[1] .. "Back.tga"), tint = a[2],
                grey = Lib.Texture(a[1] .. "BackGrey.tga"), back = a[1] .. "Back" }
        end
        return list
    end,
    statusbar = function()
        local list = {}
        for i, a in ipairs(THEME_ART) do list[i] = { name = "FQL " .. a[1], path = Lib.Texture(a[1] .. "Bar.tga") } end
        return list
    end,
}
Media.OWN = setmetatable({}, { __index = function(_, kind) return OWN[kind] and OWN[kind]() end })

-- Every built-in file of a kind: the game's, then the themes'.
local function builtIn(kind)
    local list = {}
    for _, source in ipairs({ Media.BLIZZARD, Media.OWN }) do
        for _, f in ipairs(source[kind]) do list[#list + 1] = f end
    end
    return list
end

Media.DEFAULT = {
    font = "Fonts\\FRIZQT__.TTF",
    background = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    statusbar = "Interface\\Buttons\\WHITE8X8",
}

local function sharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Every name of a kind ("font", "background", "statusbar"), Blizzard's
-- first, then LibSharedMedia's sorted.
function Media.Names(kind)
    local names, seen = {}, {}
    for _, f in ipairs(builtIn(kind)) do
        names[#names + 1] = f.name
        seen[f.name] = true
    end
    local lsm = sharedMedia()
    if lsm then
        local extra = {}
        for _, name in ipairs(lsm:List(kind) or {}) do
            if not seen[name] then extra[#extra + 1] = name end
        end
        table.sort(extra)
        for _, name in ipairs(extra) do names[#names + 1] = name end
    end
    return names
end

-- The file for a name; unknown names get the kind's default. A font stored
-- under an older name (LibForeverThemes' aliases) finds its file.
function Media.Path(kind, name)
    if kind == "font" then name = Lib.FontName(name) end
    for _, f in ipairs(builtIn(kind)) do
        if f.name == name then return f.path end
    end
    local lsm = sharedMedia()
    local path = lsm and lsm:Fetch(kind, name, true)
    return path or Media.DEFAULT[kind]
end

-- How much a built-in background is darkened (1: not at all).
function Media.Tint(name)
    for _, f in ipairs(builtIn("background")) do
        if f.name == name then return f.tint or 1 end
    end
    return 1
end

function Media.FontNames() return Media.Names("font") end

-- Whether a text took the font asked for.
local function hasFont(fs, path)
    local got = fs:GetFont()
    if type(got) ~= "string" then return false end
    local function plain(p) return (p:lower():gsub("/", "\\")) end
    return plain(got) == plain(path)
end
-- Where the themes' font files lie, in whichever addon's copy of the
-- library won.
local THEME_FONTS = "\\Libs\\LibForeverThemes\\Media\\Fonts\\"
-- How often, and how far apart, a refused font is tried again.
local FONT_RETRIES, FONT_RETRY_DELAY = 40, 0.25
-- First use of a file can take seconds when many fonts load at once
-- (theme switch); report each file only once.
local refusedFonts = {}

-- A font file used for the first time can leave a text blank although
-- GetFont reports it (seen in game: empty texts until the theme was
-- chosen a second time). Setting it again a little later, through another
-- font, as that second choice did, draws them. Once per text and font.
local REDRAW_DELAYS = { 0.5, 2 }
local function redrawLater(fs, path, size, flags, wanted)
    if fs.fontDrawn == wanted then return end
    fs.fontDrawn = wanted
    for _, delay in ipairs(REDRAW_DELAYS) do
        C_Timer.After(delay, function()
            if fs.fontWanted ~= wanted then return end
            fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
            fs:SetFont(path, size, flags)
            local text = fs:GetText()
            if text then fs:SetText(""); fs:SetText(text) end
        end)
    end
end

-- A font file used for the first time (the themes' own) can be refused and
-- leave the text without a font (seen in Forever Unit Frames): the client's
-- font meanwhile, ours tried again a few times.
local function setFont(fs, path, size, outline, retries)
    local wanted = path .. "|" .. size .. "|" .. outline
    fs.fontWanted = wanted
    -- Only the themes' files are checked by name: another addon's path may
    -- come back from GetFont written differently.
    local ok = fs:SetFont(path, size, outline)
    if ok and (not path:find(THEME_FONTS, 1, true) or hasFont(fs, path)) then
        redrawLater(fs, path, size, outline, wanted)
        return
    end
    fs:SetFont(Media.DEFAULT.font, size, outline)
    if path == Media.DEFAULT.font then return end
    if retries == 0 then
        if not refusedFonts[path] then ns.Print(ns.L.MSG_FONT_FAILED:format(path)) end
        refusedFonts[path] = true
        return
    end
    C_Timer.After(FONT_RETRY_DELAY, function()
        -- Restyled since: that call has its own tries.
        if fs.fontWanted == wanted then setFont(fs, path, size, outline, (retries or FONT_RETRIES) - 1) end
    end)
end
function Media.FontPath(name) return Media.Path("font", name) end

-- A text style (Settings.TextStyle) on a font string. SHADOW is a drop
-- shadow, the other flags are outlines.
function Media.ApplyText(fs, style)
    local flag = style.flag
    local outline = (flag == "OUTLINE" or flag == "THICKOUTLINE") and flag or ""
    setFont(fs, Media.FontPath(style.font), style.size, outline)
    if flag == "SHADOW" then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    local c = style.color
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- A background texture: SOLID (colour), GRADIENT (colour fading down) or
-- TEXTURE (tiled, alpha only). alpha 0..1.
-- A theme colour (Themes.BackColor) on the theme's own backdrop: a comic
-- paper tints the paper; any other colour draws the grey version tinted
-- to its mean colour (vertex colour back / the grey's mean, at most 1).
local function themeArt(name)
    for _, f in ipairs(Media.OWN.background) do
        if f.name == name then return f end
    end
end

function Media.ApplyBackground(tex, mode, color, alpha, textureName)
    if mode == "TEXTURE" then
        local c = ns.Themes.BackColor(textureName)
        local art = c and c.back and themeArt(textureName)
        local mean = art and Lib.GREY_MEAN[art.back]
        tex:SetTexture(mean and art.grey or Media.Path("background", textureName), "REPEAT", "REPEAT")
        tex:SetHorizTile(true)
        tex:SetVertTile(true)
        if mean then
            local b = c.back
            tex:SetVertexColor(math.min(1, b[1] / mean), math.min(1, b[2] / mean), math.min(1, b[3] / mean), alpha)
        elseif c and c.paper then
            tex:SetVertexColor(c.paper[1], c.paper[2], c.paper[3], alpha)
        else
            local tint = Media.Tint(textureName)
            tex:SetVertexColor(tint, tint, tint, alpha)
        end
        return
    end
    tex:SetHorizTile(false)
    tex:SetVertTile(false)
    tex:SetColorTexture(1, 1, 1, 1)
    local c = color
    local top = CreateColor(c[1], c[2], c[3], alpha)
    local bottom = mode == "GRADIENT" and CreateColor(c[1], c[2], c[3], alpha * 0.35) or top
    tex:SetGradient("VERTICAL", bottom, top)
end

-- Blizzard's font on one of its font strings, remembered before we change
-- it, and put back. SetFontObject alone does not restore: after SetFont the
-- string still names the same font object, and setting that one again
-- changes nothing (seen in game). So file, size, flags and shadow go back
-- explicitly.
function Media.Snapshot(fs)
    local file, size, flags = fs:GetFont()
    local sx, sy = fs:GetShadowOffset()
    local r, g, b, a = fs:GetShadowColor()
    local tr, tg, tb, ta = fs:GetTextColor()
    return { object = fs:GetFontObject(), file = file, size = size, flags = flags or "",
             shadow = { sx or 0, sy or 0 }, shadowColor = { r or 0, g or 0, b or 0, a or 1 },
             color = { tr or 1, tg or 1, tb or 1, ta or 1 } }
end

function Media.Restore(fs, o, withColor)
    if o.file then fs:SetFont(o.file, o.size, o.flags) end
    if o.object then fs:SetFontObject(o.object) end
    fs:SetShadowOffset(o.shadow[1], o.shadow[2])
    fs:SetShadowColor(o.shadowColor[1], o.shadowColor[2], o.shadowColor[3], o.shadowColor[4])
    if withColor then fs:SetTextColor(o.color[1], o.color[2], o.color[3], o.color[4]) end
end
