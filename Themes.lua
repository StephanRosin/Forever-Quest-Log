local ADDON, ns = ...
local Settings = ns.Settings

-- Themes (beta): a look for the tracker, the focus frame and the notes, and
-- a whole set of settings each, built like Forever Unit Frames' themes (same
-- ids, fonts and art; no link between the two addons). The setting `theme`
-- names the one in use; the active profile holds its settings, the others
-- wait in ns.ThemeSets() (Profiles.lua), per profile. CLASSIC is the
-- player's own setup as it was before themes: no other theme ever changes
-- it, so going back to it restores every setting.
--
-- A theme chosen the first time starts from the CLASSIC set (position,
-- size, everything the player set up) with the theme's look on top.
local Themes = {}
ns.Themes = Themes

local CLASSIC = "CLASSIC"
Themes.CLASSIC = CLASSIC
Themes.IDS = Settings.THEMES

-- The theme fonts have Latin letters only: on a client whose names are
-- written otherwise the texts keep their font.
local LATIN_CLIENTS = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
    ptBR = true }

-- look: tracker settings the theme sets; the focus frame gets the same
-- under its own keys (Settings.Prefixed) where it has them. font: the
-- display texts' (header, zones and list names, quest titles);
-- fontSizeAdd: how much larger it must be to read like the others; flag:
-- their outline (default OUTLINE), so the light text stays readable on
-- every backdrop. bodyFont: the body texts' (objectives, task rows, done
-- lines), nil = font; set where the theme font is unreadable at small
-- sizes or over several lines. Body texts get bodyFlag (default OUTLINE),
-- and fontSizeAdd only with the theme font. Frost's texts have a soft
-- drop shadow (SHADOW) instead of an outline.
-- Body text is light with an
-- outline, or dark ink on a light backdrop (comic): one or the other,
-- never mixed, about 4.5:1 against the backdrop. Never a hand-made outline of black text
-- copies: with these fonts it showed black text in Forever Unit Frames.
-- bar: the objective bars' texture. The backdrop is the frame's background
-- (bgTexture "FQL <name>", Media.lua), so it frames the whole list.
-- art (Themes.DrawArt): ornament = corner piece in Media/Themes, corners =
-- which ones (Corners.POINTS order: 1 top left, 2 top right, 3 bottom
-- left, 4 bottom right), ornamentInset = how far in from the ring's outer
-- corner (negative: further out), hardShadow = offset of a solid shadow,
-- shade = a colour laid over the backdrop behind the content (below the
-- header, inside a band of shadeInset), so a busy backdrop only frames it;
-- band = a strip { color, height } along the top inside the edge (height
-- nil: the header's), with wedge = a piece in Media/Themes at its start, as
-- high and as wide as the band (wedgeColor), and rule = a 1 px line's colour
-- under it. icons: the header icons' colours (idle, hover, on, off), grip =
-- the resize grips', close = the close button's icon (Media.Icon) instead of
-- the game's gold X.
Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards, a gold rim, brass rivets.
    WOOD = {
        font = "Cinzel", bodyFont = "Friz Quadrata", bar = "FQL Wood",
        look = { borderStyle = "GOLD", borderSize = 3, cornerRadius = 4, shadowEnabled = true, shadowSize = 6,
            shadowAlpha = 60, bgMode = "TEXTURE", bgTexture = "FQL Wood", bgAlpha = 100, headerShine = false },
        art = { ornament = "Rivet", corners = { 1, 2, 3, 4 }, ornamentSize = 11, ornamentInset = 1 },
    },
    -- Dark navy with a faint grid, a thin cyan line, corner brackets.
    TECH = {
        font = "Space Grotesk", bar = "FQL Tech",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.25, 0.88, 0.94, 0.9 }, cornerRadius = 0,
            shadowEnabled = false, bgMode = "TEXTURE", bgTexture = "FQL Tech", bgAlpha = 100, headerShine = false,
            headerColor = { 0.25, 0.88, 0.94 }, titleColor = { 0.62, 0.93, 1 } },
    },
    -- Parchment, a brown ink line, a wax seal.
    PARCHMENT = {
        font = "IM Fell English SC", bodyFont = "Friz Quadrata", bar = "FQL Parchment", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.29, 0.2, 0.12, 1 }, cornerRadius = 2,
            shadowEnabled = true, shadowSize = 5, shadowAlpha = 45, bgMode = "TEXTURE", bgTexture = "FQL Parchment",
            bgAlpha = 100, headerShine = false, headerColor = { 1, 0.9, 0.7 } },
        art = { ornament = "Seal", corners = { 3 }, ornamentSize = 22, ornamentInset = 2 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        font = "Marcellus", bar = "FQL Stone", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.1, 0.1, 0.12, 1 }, cornerRadius = 0,
            shadowEnabled = true, shadowSize = 6, shadowAlpha = 70, bgMode = "TEXTURE", bgTexture = "FQL Stone",
            bgAlpha = 100, headerShine = false, headerColor = { 0.35, 0.95, 0.85 }, titleColor = { 0.85, 0.95, 0.92 } },
        art = { ornament = "Rune", corners = { 1, 2 }, ornamentSize = 14, ornamentInset = 2,
            ornamentColor = { 0.35, 0.95, 0.85, 1 } },
    },
    -- A mosaic of coloured glass, dark lead, the gold shine behind the title.
    GLASS = {
        font = "Morpheus", bodyFont = "Friz Quadrata", bar = "FQL Glass", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.06, 0.05, 1 }, cornerRadius = 0,
            shadowEnabled = true, shadowSize = 6, shadowAlpha = 55, bgMode = "TEXTURE", bgTexture = "FQL Glass",
            bgAlpha = 100, headerShine = true },
        art = { shade = { 0.05, 0.04, 0.06, 0.9 }, shadeInset = 6 },
    },
    -- Thick ink line, halftone paper, a solid shadow.
    COMIC = {
        font = "Bangers", bodyFont = "Friz Quadrata", bar = "FQL Comic", fontSizeAdd = 2, flag = "OUTLINE",
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.07, 0.07, 1 }, cornerRadius = 0,
            shadowEnabled = false, bgMode = "TEXTURE", bgTexture = "FQL Comic", bgAlpha = 100, headerShine = false,
            headerColor = { 1, 0.9, 0.1 }, titleColor = { 1, 1, 1 }, objectiveColor = { 0.1, 0.1, 0.1 },
            objectiveDoneColor = { 0.33, 0.33, 0.33 }, doneColor = { 0.05, 0.4, 0.1 } },
        bodyFlag = "",
        -- Level colours in body text (light on the paper) darkened this much.
        ink = 0.55,
        -- Header icons in ink: the light ones vanish on the paper.
        icons = { idle = { 0.12, 0.12, 0.12 }, hover = { 0, 0, 0 }, on = { 0.75, 0.1, 0.05 }, off = { 0.38, 0.36, 0.33 } },
        art = {},
    },
    -- Translucent ice, a pale rim, rounded.
    FROST = {
        font = "Julius Sans One", bodyFont = "Julius Sans One", bar = "FQL Frost", flag = "SHADOW",
        bodyFlag = "SHADOW",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.86, 0.96, 1, 0.8 }, cornerRadius = 6,
            shadowEnabled = true, shadowSize = 8, shadowAlpha = 55, bgMode = "TEXTURE", bgTexture = "FQL Frost",
            bgAlpha = 85, headerShine = false, headerColor = { 0.86, 0.96, 1 }, titleColor = { 0.72, 0.88, 1 } },
        art = { shade = { 0.02, 0.07, 0.15, 0.45 }, shadeInset = 4 },
    },
    -- A light pixel frame, scan lines, a solid shadow.
    PIXEL = {
        font = "VT323", bar = "FQL Pixel", fontSizeAdd = 4,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 }, cornerRadius = 0,
            shadowEnabled = false, bgMode = "TEXTURE", bgTexture = "FQL Pixel", bgAlpha = 100, headerShine = false,
            headerColor = { 1, 0.95, 0.91 }, titleColor = { 0.55, 1, 0.55 } },
        art = {},
    },
    -- Swiss style: flat black, a white rule along the top, grey hairlines,
    -- one red accent.
    SWISS = {
        font = "Inter Tight Bold", bodyFont = "Inter Tight", bar = "FQL Swiss",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.165, 0.165, 0.165, 1 }, cornerRadius = 0,
            shadowEnabled = false, bgMode = "TEXTURE", bgTexture = "FQL Swiss", bgAlpha = 100, headerShine = false,
            headerLine = false, headerColor = { 1, 0.176, 0.125 }, zoneColor = { 0.549, 0.549, 0.549 },
            titleColor = { 0.949, 0.949, 0.949 }, objectiveColor = { 0.949, 0.949, 0.949 },
            objectiveDoneColor = { 0.549, 0.549, 0.549 } },
        art = { band = { color = { 0.949, 0.949, 0.949, 1 }, height = 3 } },
    },
    -- A terminal: near black, a mint line, monospaced text.
    CONSOLE = {
        font = "IBM Plex Sans Condensed Bold", bodyFont = "IBM Plex Mono", bar = "FQL Console",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.306, 0.929, 0.69, 1 }, cornerRadius = 0,
            shadowEnabled = false, bgMode = "TEXTURE", bgTexture = "FQL Console", bgAlpha = 100, headerShine = false,
            headerLine = false, headerColor = { 0.306, 0.929, 0.69 }, zoneColor = { 0.627, 0.471, 1 },
            titleColor = { 0.902, 0.91, 0.933 }, objectiveColor = { 0.902, 0.91, 0.933 },
            objectiveDoneColor = { 0.545, 0.565, 0.627 } },
    },
    -- A motorsport timing screen: flat black with a carbon hairline, a black title strip with
    -- a red wedge, the content on a black card.
    PITWALL = {
        font = "Titillium Web Bold Italic", bodyFont = "Titillium Web SemiBold", bar = "FQL Pitwall",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.043, 0.047, 0.055, 1 }, cornerRadius = 0,
            shadowEnabled = false, bgMode = "TEXTURE", bgTexture = "FQL Swiss", bgAlpha = 100, headerShine = false, headerLine = false,
            headerColor = { 0.949, 0.953, 0.961 }, zoneColor = { 0.949, 0.953, 0.961 },
            titleColor = { 0.949, 0.953, 0.961 }, objectiveColor = { 0.949, 0.953, 0.961 },
            objectiveDoneColor = { 0.604, 0.631, 0.671 }, doneColor = { 0.133, 0.773, 0.369 } },
        -- The icons in the wedge's colour (Themes.Icons), a plain X.
        icons = { close = "Close" },
        art = { band = { color = { 0, 0, 0, 1 }, wedge = "PitwallWedge", wedgeColor = { 0.882, 0.024, 0, 1 },
            rule = { 0.137, 0.149, 0.173, 1 } } },
    },
}

-- Raised whenever SPECS change a look: theme sets made before are made anew
-- from CLASSIC (Themes.Upgrade), so a changed theme shows as it is now.
-- CLASSIC is never touched.
Themes.REVISION = 11

-- What "Take positions from" takes over: where the frames sit, not how big
-- they are.
Themes.PLACEMENT = { "point", "x", "y", "grow", "focusPoint", "focusX", "focusY", "mapPlaced", "mapPoint", "mapX",
    "mapY", "questDialogPlaced", "questDialogPoint", "questDialogX", "questDialogY", "minimapAngle" }

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

function Themes.Current() return Settings.Get("theme") end

function Themes.Spec(id) return Themes.SPECS[id] or Themes.SPECS.CLASSIC end

-- Theme colours: a backdrop colour and an accent per theme, picked apart
-- from the theme sets: kept next to them per profile (themeColors =
-- { [theme] = colour id }), so switching themes never loses them and the
-- stored looks stay as they are (applied when drawn). The first colour of
-- each theme is the theme as it was (nothing applied). Same ids and values
-- in every Forever addon.
-- paper (COMIC): the tint of the theme's own light paper; dark: on a dark
-- paper what is dark ink elsewhere is drawn light. back (every other
-- theme): the mean colour the backdrop is drawn in, from a grey version of
-- the theme's texture (<Name>BackGrey.tga). accent: the heading colour
-- instead of the theme's; none = the theme's. rim: the border colour
-- instead of the stored one (only Console's colours and Handheld: every
-- Forever addon draws the same ring per theme and colour); ornament: the
-- ornaments' colour and the band's wedge's.
local YELLOW_ACCENT = { 1.00, 0.90, 0.10 }
local BLUE_ACCENT = { 0.15, 0.45, 0.95 }
local PICO_YELLOW = { 1, 0.93, 0.15 }
local HANDHELD_GREEN = { 0.784, 0.941, 0.439, 1 }
Themes.COLORS = {
    WOOD = {
        { id = "OAK" },
        { id = "WALNUT", back = { 0.15, 0.09, 0.06 } },
        { id = "BIRCH", back = { 0.38, 0.32, 0.22 } },
        { id = "CHERRY", back = { 0.30, 0.12, 0.08 } },
        { id = "EBONY", back = { 0.08, 0.07, 0.07 } },
        { id = "DRIFTWOOD", back = { 0.25, 0.24, 0.22 } },
    },
    TECH = {
        { id = "CYAN" },
        { id = "GREEN", back = { 0.02, 0.10, 0.05 }, accent = { 0.30, 0.95, 0.45 } },
        { id = "AMBER", back = { 0.10, 0.07, 0.02 }, accent = { 1, 0.75, 0.20 } },
        { id = "MAGENTA", back = { 0.09, 0.03, 0.10 }, accent = { 0.95, 0.40, 0.95 } },
        { id = "BLUE", back = { 0.03, 0.05, 0.13 }, accent = { 0.45, 0.65, 1 } },
        { id = "GREY", back = { 0.07, 0.07, 0.08 }, accent = { 0.85, 0.88, 0.90 } },
    },
    PARCHMENT = {
        { id = "CLASSIC" },
        { id = "AGED", back = { 0.32, 0.25, 0.15 } },
        { id = "ASH", back = { 0.33, 0.33, 0.31 } },
        { id = "SEA", back = { 0.25, 0.30, 0.33 } },
        { id = "ROSE", back = { 0.36, 0.27, 0.26 } },
        { id = "DARK", back = { 0.20, 0.17, 0.13 } },
    },
    RUNESTONE = {
        { id = "GRANITE" },
        { id = "SANDSTONE", back = { 0.33, 0.27, 0.18 }, accent = { 1, 0.80, 0.35 } },
        { id = "SLATE", back = { 0.15, 0.18, 0.25 }, accent = { 0.55, 0.75, 1 } },
        { id = "MOSS", back = { 0.15, 0.22, 0.14 }, accent = { 0.50, 1, 0.45 } },
        { id = "OBSIDIAN", back = { 0.07, 0.06, 0.09 }, accent = { 0.75, 0.50, 1 } },
    },
    GLASS = {
        { id = "CATHEDRAL" },
        { id = "BLUE", back = { 0.08, 0.12, 0.28 } },
        { id = "GREEN", back = { 0.07, 0.20, 0.10 } },
        { id = "AMBER", back = { 0.28, 0.17, 0.05 } },
        { id = "VIOLET", back = { 0.18, 0.08, 0.26 } },
        { id = "RUBY", back = { 0.26, 0.05, 0.08 } },
    },
    COMIC = {
        { id = "GREY" },
        { id = "DARKGREY", paper = { 0.38, 0.38, 0.38 }, accent = YELLOW_ACCENT, dark = true },
        { id = "BLACK", paper = { 0.16, 0.16, 0.16 }, accent = YELLOW_ACCENT, dark = true },
        { id = "WHITE", paper = { 1.00, 1.00, 1.00 }, accent = BLUE_ACCENT },
        { id = "YELLOW", paper = { 0.86, 0.76, 0.36 }, accent = BLUE_ACCENT },
        { id = "BLUE", paper = { 0.45, 0.60, 0.86 }, accent = YELLOW_ACCENT },
        { id = "RED", paper = { 0.86, 0.44, 0.40 }, accent = YELLOW_ACCENT },
        { id = "GREEN", paper = { 0.50, 0.76, 0.46 }, accent = YELLOW_ACCENT },
        { id = "PURPLE", paper = { 0.70, 0.52, 0.84 }, accent = YELLOW_ACCENT },
    },
    FROST = {
        { id = "ICE" },
        { id = "DEEP", back = { 0.10, 0.18, 0.32 }, accent = { 0.60, 0.85, 1 } },
        { id = "AURORA", back = { 0.10, 0.27, 0.24 }, accent = { 0.55, 1, 0.80 } },
        { id = "VIOLET", back = { 0.22, 0.18, 0.33 }, accent = { 0.85, 0.75, 1 } },
        { id = "SILVER", back = { 0.30, 0.31, 0.33 }, accent = { 0.92, 0.92, 0.95 } },
        { id = "NIGHT", back = { 0.06, 0.08, 0.14 }, accent = { 0.70, 0.85, 1 } },
    },
    -- PICO-8's palette.
    PIXEL = {
        { id = "NAVY" },
        { id = "PLUM", back = { 0.23, 0.08, 0.16 }, accent = PICO_YELLOW },
        { id = "FOREST", back = { 0.00, 0.20, 0.12 }, accent = PICO_YELLOW },
        { id = "BROWN", back = { 0.20, 0.12, 0.08 }, accent = { 1, 0.64, 0.00 } },
        { id = "GREY", back = { 0.18, 0.17, 0.16 } },
        { id = "BLACK", back = { 0.03, 0.03, 0.04 }, accent = { 0, 0.89, 0.21 } },
        { id = "TEAL", back = { 0.02, 0.17, 0.22 }, accent = { 0.16, 0.68, 1 } },
        { id = "PURPLE", back = { 0.15, 0.10, 0.25 }, accent = { 1, 0.47, 0.66 } },
        { id = "HANDHELD", back = { 0.059, 0.122, 0.059 }, accent = HANDHELD_GREEN, rim = HANDHELD_GREEN },
    },
    -- The backdrop stays in every colour of the last three.
    SWISS = {
        { id = "RED" },
        { id = "BLUE", accent = { 0.176, 0.42, 1 } },
        { id = "YELLOW", accent = { 1, 0.82, 0 } },
        { id = "WHITE", accent = { 0.949, 0.949, 0.949 } },
    },
    -- The line follows the accent.
    CONSOLE = {
        { id = "MINT" },
        { id = "AMBER", accent = { 1, 0.69, 0 }, rim = { 1, 0.69, 0, 1 } },
        { id = "PHOSPHOR", accent = { 0.224, 1, 0.078 }, rim = { 0.224, 1, 0.078, 1 } },
        { id = "VIOLET", accent = { 0.627, 0.471, 1 }, rim = { 0.627, 0.471, 1, 1 } },
    },
    -- The wedge's colour.
    PITWALL = {
        { id = "RED" },
        { id = "ORANGE", ornament = { 1, 0.541, 0, 1 } },
        { id = "TEAL", ornament = { 0, 0.631, 0.612, 1 } },
        { id = "SILVER", ornament = { 0.788, 0.808, 0.839, 1 } },
    },
}
-- The mean grey of each <Name>BackGrey.tga: a backdrop colour is drawn as
-- vertex colour back / mean (at most 1). Swiss, Console and Pitwall have
-- no back colours, so no grey file.
Themes.GREY_MEAN = { Wood = 0.800, Tech = 0.705, Parchment = 0.799, Stone = 0.800, Glass = 0.777, Frost = 0.796,
    Pixel = 0.800 }

-- The colour ids of themeId (default the current theme) in menu order;
-- none for CLASSIC.
function Themes.Colors(themeId)
    local list = {}
    for _, c in ipairs(Themes.COLORS[themeId or Themes.Current()] or {}) do list[#list + 1] = c.id end
    return list
end

local function colorOf(themeId, id)
    for _, c in ipairs(Themes.COLORS[themeId] or {}) do
        if c.id == id then return c end
    end
end

-- The stored choices; a comicColor from before them moved in once.
local function chosen()
    local sets = ns.ThemeSets()
    sets.themeColors = sets.themeColors or {}
    if sets.comicColor then
        sets.themeColors.COMIC = sets.themeColors.COMIC or sets.comicColor
        sets.comicColor = nil
    end
    return sets.themeColors
end

-- The colour id of themeId (default the current theme): the stored one or
-- the theme's first; nil for CLASSIC.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    local list = Themes.COLORS[themeId]
    if not list then return nil end
    local id = chosen()[themeId]
    return colorOf(themeId, id) and id or list[1].id
end

-- The colour in use, nil while it is the theme's first (the theme as it is).
local function palette()
    local themeId = Themes.Current()
    local id = Themes.Color(themeId)
    if not id or id == Themes.COLORS[themeId][1].id then return nil end
    return colorOf(themeId, id)
end

-- The colour (back or paper, Media.ApplyBackground) for the backdrop
-- textureName: while it is the current theme's own and a colour is picked,
-- else nil.
function Themes.BackColor(textureName)
    local p = palette()
    if not p or textureName ~= Themes.Spec(Themes.Current()).look.bgTexture then return nil end
    return p
end

-- The header colour to draw: the colour's accent, or color as stored.
function Themes.Accent(color)
    local p = palette()
    return p and p.accent or color
end

-- The border colour to draw: the colour's rim, or color as stored.
function Themes.Rim(color)
    local p = palette()
    return p and p.rim or color
end

-- Light ink for a dark paper: body text and the header icons.
local LIGHT_TEXT = { 0.9, 0.9, 0.9 }
local LIGHT_ICONS = { idle = { 0.85, 0.85, 0.85 }, hover = { 1, 1, 1 }, off = { 0.55, 0.55, 0.55 },
    on = YELLOW_ACCENT }

local function darkPaper()
    local p = palette()
    return p ~= nil and p.dark == true
end

-- A body text colour on the backdrop: light on a dark comic paper (where
-- the theme's dark ink would vanish), else color.
function Themes.OnPaper(color)
    return darkPaper() and LIGHT_TEXT or color
end

-- The colour the header icons take: the colour's accent (the title's), on
-- Pitwall the wedge's, as the colour changes it there.
local function iconAccent(spec)
    local band, p = spec.art and spec.art.band, palette()
    local c = band and band.wedge and (p and p.ornament or band.wedgeColor) or Themes.Accent(Settings.Get("headerColor"))
    return { c[1], c[2], c[3] }
end

-- Toward `to` (0 black, 1 white) by share f.
local function mix(c, to, f)
    return { c[1] + (to - c[1]) * f, c[2] + (to - c[2]) * f, c[3] + (to - c[3]) * f }
end

-- The same in every Forever addon: under a hover the accent half way to
-- white, a toggle that is off 40 % darker.
local ICON_HOVER, ICON_OFF = 0.5, 0.4

-- The header icons' colours (idle, hover, on, off, grip; close = the close
-- button's icon), nil = the addon's own (CLASSIC). A theme with its own ink
-- (COMIC: dark on the light paper, light on a dark one) keeps it; every
-- other draws them in the colour's accent.
function Themes.Icons()
    if darkPaper() then return LIGHT_ICONS end
    local id = Themes.Current()
    local spec = Themes.Spec(id)
    if id == CLASSIC or (spec.icons and spec.icons.idle) then return spec.icons end
    local a = iconAccent(spec)
    return { idle = a, on = a, grip = a, hover = mix(a, 1, ICON_HOVER), off = mix(a, 0, ICON_OFF),
        close = spec.icons and spec.icons.close }
end

-- A colour for body text: darkened on a theme with dark ink (COMIC), so
-- the client's light level colours stay readable without an outline. On a
-- dark comic paper they stay light, as they are.
function Themes.Ink(c)
    local ink = Themes.Spec(Themes.Current()).ink
    if not ink or darkPaper() then return c end
    return { r = c.r * ink, g = c.g * ink, b = c.b * ink }
end

-- The active profile's stored sets; stale ones (an older REVISION) dropped.
local function storedSets()
    local sets = ns.ThemeSets()
    if sets.revision ~= Themes.REVISION then
        for _, id in ipairs(Themes.IDS) do
            if id ~= CLASSIC then sets[id] = nil end
        end
        sets.revision = Themes.REVISION
    end
    return sets
end

-- A value into a set as the profile stores it: nothing when it is the
-- default; keys the addon does not have (the focus frame lacks some) skipped.
local function put(set, key, value)
    local default = Settings.DEFAULTS[key]
    if default == nil then return end
    if Settings.SameValue(value, default) then value = nil end
    set[key] = copy(value)
end

local function valueIn(set, key)
    local v = set[key]
    if v == nil then v = Settings.DEFAULTS[key] end
    return v
end

-- The text styles for running text; the others are display texts.
local BODY = { objective = true, done = true }

-- The tracker's key, and the focus frame's for the same setting.
local FRAMES = { function(k) return k end, Settings.Prefixed("focus").key }

-- A new theme's settings: the base set (CLASSIC) with the theme's look.
local function seed(id, base)
    local spec = Themes.Spec(id)
    local set = copy(base)
    local latin = LATIN_CLIENTS[GetLocale()]
    for _, key in ipairs(FRAMES) do
        for k, v in pairs(spec.look) do put(set, key(k), v) end
        put(set, key("barTexture"), spec.bar)
        for _, style in ipairs(Settings.TEXT_STYLES) do
            local size = key(style .. "Size")
            if Settings.DEFAULTS[size] ~= nil then
                local body = BODY[style]
                local font = body and spec.bodyFont or spec.font
                if latin then put(set, key(style .. "Font"), font) end
                local flag = body and (spec.bodyFlag or "OUTLINE") or spec.flag or "OUTLINE"
                put(set, key(style .. "Flag"), flag)
                if latin and style == "done" and spec.bodyFont then
                    -- Classic's doneSize suits Arial Narrow; in the body font it would outgrow the
                    -- objectives. Their size is final here (TEXT_STYLES lists objective first).
                    put(set, size, valueIn(set, key("objectiveSize")))
                elseif font == spec.font then
                    put(set, size, math.min(Settings.RANGES[size][2], valueIn(set, size) + (spec.fontSizeAdd or 0)))
                end
            end
        end
    end
    put(set, "theme", id)
    return set
end

-- Replaces the active profile's settings with set.
local function fill(set)
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(set) do db[k] = v end
end

local function use(set)
    fill(set)
    Settings.Changed(nil)
end

-- Restyling moves the tracker; the quest item buttons (secure) could not
-- follow in combat.
local function refused()
    if InCombatLockdown() then return "COMBAT" end
end

-- Moves to theme id: the current settings are kept for the current theme,
-- id's come back (or are made, the first time). true, or nil and why not.
function Themes.Switch(id)
    if not Themes.SPECS[id] then return nil, "UNKNOWN" end
    local why = refused()
    if why then return nil, why end
    local current = Themes.Current()
    if id == current then return true end
    local sets = storedSets()
    sets[current] = copy(ns.DB())
    local nextSet = sets[id]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one (a
        -- profile imported with a theme) the settings stay as they are.
        local base = sets[CLASSIC] or ns.DB()
        nextSet = id == CLASSIC and copy(base) or seed(id, base)
    end
    put(nextSet, "theme", id)
    -- The live set is the profile: no stale copy stays behind.
    sets[id] = nil
    use(nextSet)
    return true
end

-- The current theme made anew from CLASSIC. Not for CLASSIC itself.
function Themes.Reset()
    local id = Themes.Current()
    if id == CLASSIC then return nil, "CLASSIC" end
    local why = refused()
    if why then return nil, why end
    local base = storedSets()[CLASSIC]
    if not base then return nil, "NO_CLASSIC" end
    use(seed(id, base))
    return true
end

-- Picks colour id for themeId (default the current theme); repaints at once
-- while that theme is in use. true, or nil and why not.
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not colorOf(themeId, id) then return nil, "UNKNOWN" end
    local repaint = themeId == Themes.Current()
    local why = repaint and refused()
    if why then return nil, why end
    chosen()[themeId] = id
    if repaint then Settings.Changed(nil) end
    return true
end

-- The themes with stored settings to copy from, in IDS order.
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Themes.IDS) do
        if sets[id] and id ~= Themes.Current() then list[#list + 1] = id end
    end
    return list
end

-- The positions of theme `from` taken over into the current one. Returns
-- what it replaced (Themes.Restore puts it back), or nil and why not.
function Themes.CopyPlacement(from)
    local why = refused()
    if why then return nil, why end
    local source = storedSets()[from]
    if not source then return nil, "GONE" end
    local db, undo = ns.DB(), {}
    for _, key in ipairs(Themes.PLACEMENT) do
        undo[key] = { db[key] }   -- in a table: nil is a value here
        db[key] = copy(source[key])
    end
    Settings.Changed(nil)
    return undo
end

function Themes.Restore(undo)
    local why = refused()
    if why then return nil, why end
    local db = ns.DB()
    for key, saved in pairs(undo) do db[key] = saved[1] end
    Settings.Changed(nil)
    return true
end

-- At login, before the frames are built: a theme in use made under an
-- older REVISION is made anew from CLASSIC, quietly.
function Themes.Upgrade()
    local sets = ns.ThemeSets()
    if sets.revision == Themes.REVISION then return end
    local current, base = Themes.Current(), sets[CLASSIC]
    storedSets()
    if current == CLASSIC or not base then return end
    fill(seed(current, base))
end

-- For a central theme picker in another addon (same ids in every Forever
-- addon). Current/Switch work from PLAYER_LOGIN on; Switch is the options'
-- choice (the window follows every settings change).
_G.ForeverThemes = _G.ForeverThemes or {}
_G.ForeverThemes[ADDON] = {
    title = "Forever Quest Log",
    Current = function() return Themes.Current() end,
    Switch = function(id) return Themes.Switch(id) end,
    -- After another addon (the InfoPanel's right column) wrote the stored
    -- settings: apply them as after a change in the options.
    Refresh = function() Settings.Changed(nil) end,
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId) return Themes.SetColor(id, themeId) end,
}

-- "Apply to all Forever addons" (the options' theme rows): the other addons
-- in the list above. Each Forever addon has its own copy of this.
local function otherThemes()
    local list = {}
    for folder, entry in pairs(_G.ForeverThemes) do
        if folder ~= ADDON and type(entry) == "table" and type(entry.Switch) == "function" then
            list[#list + 1] = entry
        end
    end
    return list
end

function Themes.HasOthers() return #otherThemes() > 0 end

local function listed(ids, id)
    for _, v in ipairs(ids or {}) do
        if v == id then return true end
    end
    return false
end

-- Every other addon onto this theme and, where that theme has it, this
-- colour (else it keeps its own). One without the theme refuses the switch
-- and is skipped. Returns how many switched.
function Themes.ApplyToAll()
    local theme, color, switched = Themes.Current(), Themes.Color(), 0
    for _, entry in ipairs(otherThemes()) do
        if entry.Switch(theme) then
            switched = switched + 1
            if color and type(entry.Colors) == "function" and type(entry.SetColor) == "function"
                and listed(entry.Colors(theme), color) then
                entry.SetColor(color, theme)
            end
        end
    end
    return switched
end

-- Art --------------------------------------------------------------------------

-- The theme's art beyond settings on a frame drawn by Border.Draw (the
-- tracker, the focus frame, a note): ornaments at the ring's outer corners
-- and a solid shadow outside it. Plain textures only, nothing clickable.
local ART = "Interface\\AddOns\\ForeverQuestLog\\Media\\Themes\\"

-- Kept on the owner as owner.themeArt.
local function artOf(owner)
    local a = owner.themeArt
    if a then return a end
    a = { ornaments = {}, shadow = {} }
    -- The shadow's two strips, right and below: the frame's own background
    -- covers the rest, so nothing has to lie under it.
    for i = 1, 2 do
        a.shadow[i] = owner:CreateTexture(nil, "BORDER", nil, -1)
        a.shadow[i]:SetColorTexture(0, 0, 0, 1)
    end
    -- Over the background (BACKGROUND), under every text (child frames).
    a.shade = owner:CreateTexture(nil, "BORDER")
    a.band = owner:CreateTexture(nil, "BORDER", nil, 1)
    a.rule = owner:CreateTexture(nil, "BORDER", nil, 2)
    a.wedge = owner:CreateTexture(nil, "BORDER", nil, 3)
    -- Above the ring (OVERLAY sublevels 0 and 1, Border.lua).
    for i = 1, 4 do a.ornaments[i] = owner:CreateTexture(nil, "OVERLAY", nil, 7) end
    owner.themeArt = a
    return a
end

-- Inside the ring along the right and bottom edge: windows stacked edge
-- to edge must not overlap under a theme (the outer edge stays Classic's).
local function placeShadow(strips, box, offset)
    local right, bottom = strips[1], strips[2]
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", box, "TOPRIGHT", -offset, -offset)
    right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    bottom:ClearAllPoints()
    bottom:SetPoint("TOPLEFT", box, "BOTTOMLEFT", offset, offset)
    bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
end

local function placeOrnaments(pieces, box, art, extent)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    local size, inset = art.ornamentSize or 12, (art.ornamentInset or 0) - extent
    local p = palette()
    local c = p and p.ornament or art.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(pieces) do
        piece:SetShown(wanted[i] == true)
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, box, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(ART .. art.ornament)
            local m = ns.Corners.COORDS[i]
            piece:SetTexCoord(m[1], m[2], m[3], m[4])
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

local function placeShade(shade, box, art, top)
    shade:SetShown(art.shade ~= nil)
    if not art.shade then return end
    local inset, c = art.shadeInset or 0, art.shade
    shade:ClearAllPoints()
    shade:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -math.max(top or 0, inset))
    shade:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
    shade:SetColorTexture(c[1], c[2], c[3], c[4])
end

-- The wedge texture is square with the slanted piece in its left part:
-- that part only, as wide as the band is high, as in Forever Unit Frames.
local WEDGE_PART = 0.53

local function bandHeight(art, top) return art.band and (art.band.height or top) or 0 end

-- Drawn as wide as high, that part's right edge runs from 0.98 of the width
-- at the top to 0.62 at the bottom; text starts TITLE_GAP past it, as in
-- every Forever addon.
local TITLE_GAP = 8

-- How far a header title (its middle mid below the band's top, default the
-- band's middle) moves right to clear the wedge of a band top high; 0 without one.
function Themes.TitleIndent(top, mid)
    local art = Themes.Spec(Themes.Current()).art
    if not (art and art.band and art.band.wedge) then return 0 end
    local h = bandHeight(art, top)
    return math.floor(0.98 * h - 0.36 * (mid or h / 2) + 0.5) + TITLE_GAP
end

local function placeWedge(wedge, band, b, h)
    wedge:SetShown(b.wedge ~= nil and h > 0)
    if not wedge:IsShown() then return end
    local p = palette()
    local c = p and p.ornament or b.wedgeColor or { 1, 1, 1, 1 }
    wedge:ClearAllPoints()
    wedge:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
    wedge:SetSize(h, h)
    wedge:SetTexture(ART .. b.wedge)
    wedge:SetTexCoord(0, WEDGE_PART, 0, 1)
    wedge:SetVertexColor(c[1], c[2], c[3], c[4])
end

local function placeRule(rule, band, b)
    rule:SetShown(b.rule ~= nil)
    if not b.rule then return end
    local c = b.rule
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(ns.Border.Snap(1, 1))
    rule:SetColorTexture(c[1], c[2], c[3], c[4])
end

local function placeBand(a, box, art, top)
    local band, b = a.band, art.band or {}
    band:SetShown(art.band ~= nil)
    placeWedge(a.wedge, band, b, bandHeight(art, top))
    placeRule(a.rule, band, b)
    if not art.band then return end
    local c = b.color
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    band:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    band:SetHeight(bandHeight(art, top))
    band:SetColorTexture(c[1], c[2], c[3], c[4])
end

-- owner's art around box for the current theme; look is the one just given
-- to Border.Draw (the ring's extent), top the height of a header the shade
-- leaves out.
function Themes.DrawArt(owner, box, look, top)
    local art = Themes.Spec(Themes.Current()).art
    if not art and not owner.themeArt then return end
    art = art or {}
    local a, extent = artOf(owner), ns.Border.Extent(look)
    placeOrnaments(a.ornaments, box, art, extent)
    placeShade(a.shade, box, art, top)
    placeBand(a, box, art, top)
    for _, strip in ipairs(a.shadow) do strip:SetShown(art.hardShadow ~= nil) end
    if art.hardShadow then placeShadow(a.shadow, box, art.hardShadow) end
end
