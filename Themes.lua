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
-- under its own keys (Settings.Prefixed) where it has them. font: every
-- text style's; fontSizeAdd: how much larger it must be to read like the
-- others; flag: the client's outline (default OUTLINE), so the light text
-- stays readable on every backdrop. Never a hand-made outline of black text
-- copies: with these fonts it showed black text in Forever Unit Frames.
-- bar: the objective bars' texture. The backdrop is the frame's background
-- (bgTexture "FQL <name>", Media.lua), so it frames the whole list.
-- art (Themes.DrawArt): ornament = corner piece in Media/Themes, corners =
-- which ones (Corners.POINTS order: 1 top left, 2 top right, 3 bottom
-- left, 4 bottom right), ornamentInset = how far in from the ring's outer
-- corner (negative: further out), hardShadow = offset of a solid shadow.
Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards, a gold rim, brass rivets.
    WOOD = {
        font = "Cinzel", bar = "FQL Wood",
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
        art = { ornament = "Bracket", corners = { 1, 2, 3, 4 }, ornamentSize = 12, ornamentInset = -3,
            ornamentColor = { 0.25, 0.88, 0.94, 1 } },
    },
    -- Parchment, a brown ink line, a wax seal.
    PARCHMENT = {
        font = "IM Fell English SC", bar = "FQL Parchment", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.29, 0.2, 0.12, 1 }, cornerRadius = 2,
            shadowEnabled = true, shadowSize = 5, shadowAlpha = 45, bgMode = "TEXTURE", bgTexture = "FQL Parchment",
            bgAlpha = 100, headerShine = false, headerColor = { 1, 0.9, 0.7 } },
        art = { ornament = "Seal", corners = { 3 }, ornamentSize = 22, ornamentInset = -6 },
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
        font = "Morpheus", bar = "FQL Glass", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.06, 0.05, 1 }, cornerRadius = 0,
            shadowEnabled = true, shadowSize = 6, shadowAlpha = 55, bgMode = "TEXTURE", bgTexture = "FQL Glass",
            bgAlpha = 100, headerShine = true },
    },
    -- Thick ink line, halftone paper, a solid shadow.
    COMIC = {
        font = "Bangers", bar = "FQL Comic", fontSizeAdd = 2, flag = "THICKOUTLINE",
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.07, 0.07, 1 }, cornerRadius = 0,
            shadowEnabled = false, bgMode = "TEXTURE", bgTexture = "FQL Comic", bgAlpha = 100, headerShine = false,
            headerColor = { 1, 0.9, 0.1 }, titleColor = { 1, 1, 1 } },
        art = { hardShadow = 5 },
    },
    -- Translucent ice, a pale rim, rounded.
    FROST = {
        font = "Cormorant SC", bar = "FQL Frost", fontSizeAdd = 2,
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.86, 0.96, 1, 0.8 }, cornerRadius = 6,
            shadowEnabled = true, shadowSize = 8, shadowAlpha = 55, bgMode = "TEXTURE", bgTexture = "FQL Frost",
            bgAlpha = 85, headerShine = false, headerColor = { 0.86, 0.96, 1 }, titleColor = { 0.72, 0.88, 1 } },
    },
    -- A light pixel frame, scan lines, a solid shadow.
    PIXEL = {
        font = "VT323", bar = "FQL Pixel", fontSizeAdd = 4,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 }, cornerRadius = 0,
            shadowEnabled = false, bgMode = "TEXTURE", bgTexture = "FQL Pixel", bgAlpha = 100, headerShine = false,
            headerColor = { 1, 0.95, 0.91 }, titleColor = { 0.55, 1, 0.55 } },
        art = { hardShadow = 4 },
    },
}

-- Raised whenever SPECS change a look: theme sets made before are made anew
-- from CLASSIC (Themes.Upgrade), so a changed theme shows as it is now.
-- CLASSIC is never touched.
Themes.REVISION = 1

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
                if latin then put(set, key(style .. "Font"), spec.font) end
                put(set, key(style .. "Flag"), spec.flag or "OUTLINE")
                put(set, size, math.min(Settings.RANGES[size][2], valueIn(set, size) + (spec.fontSizeAdd or 0)))
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
}

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
        a.shadow[i] = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
        a.shadow[i]:SetColorTexture(0, 0, 0, 1)
    end
    -- Above the ring (OVERLAY sublevels 0 and 1, Border.lua).
    for i = 1, 4 do a.ornaments[i] = owner:CreateTexture(nil, "OVERLAY", nil, 7) end
    owner.themeArt = a
    return a
end

local function placeShadow(strips, box, offset, e)
    local right, bottom = strips[1], strips[2]
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", box, "TOPRIGHT", e, e - offset)
    right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", e + offset, -e - offset)
    bottom:ClearAllPoints()
    bottom:SetPoint("TOPLEFT", box, "BOTTOMLEFT", offset - e, -e)
    bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", e + offset, -e - offset)
end

local function placeOrnaments(pieces, box, art, extent)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    local size, inset = art.ornamentSize or 12, (art.ornamentInset or 0) - extent
    local c = art.ornamentColor or { 1, 1, 1, 1 }
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

-- owner's art around box for the current theme; look is the one just given
-- to Border.Draw (the ring's extent).
function Themes.DrawArt(owner, box, look)
    local art = Themes.Spec(Themes.Current()).art
    if not art and not owner.themeArt then return end
    art = art or {}
    local a, extent = artOf(owner), ns.Border.Extent(look)
    placeOrnaments(a.ornaments, box, art, extent)
    for _, strip in ipairs(a.shadow) do strip:SetShown(art.hardShadow ~= nil) end
    if art.hardShadow then placeShadow(a.shadow, box, art.hardShadow, extent) end
end
