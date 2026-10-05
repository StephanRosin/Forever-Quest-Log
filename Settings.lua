local ADDON, ns = ...

-- Every user setting, its default and its range. The active profile
-- (Profiles.lua) stores only what differs from the default; Get falls back to
-- DEFAULTS. Set writes the profile and tells the listeners (the tracker, the
-- minimap button, the options window).
local Settings = {}
ns.Settings = Settings

-- The five text styles; each has <prefix>Font, Size, Flag and Color.
Settings.TEXT_STYLES = { "header", "zone", "title", "objective", "done" }

-- The shipped look is the author's own setup (05.10.2026): no border, the
-- texture background faded out, sorted by level, one list. The gold frame of
-- the other Forever addons is the "Forever" preset below.
Settings.DEFAULTS = {
    -- Off: Blizzard's own tracker stays, ours is not built (after /reload).
    useBlizzard = false,

    -- Position: `point` of the frame at `point` of the screen, plus x / y.
    -- Dragging picks the point from the side of the screen the frame is on
    -- and from the grow direction (TOP growing down, BOTTOM growing up).
    point = "TOPRIGHT",
    x = -3,
    y = -287,
    width = 289,
    height = 554,           -- the most it grows to
    grow = "DOWN",          -- DOWN (top edge fixed) or UP (bottom edge fixed)
    fitContent = true,      -- shrink to the content, never above height
    locked = true,
    scale = 100,            -- percent

    -- What the list shows and how it is ordered.
    groupByZone = false,
    currentZoneFirst = true,
    sortBy = "LEVEL",       -- WATCH (Blizzard's order) or LEVEL
    showLevel = true,
    levelColors = true,     -- difficulty colours for "[34]"; else the title colour
    showTags = true,        -- Elite, Dungeon, ...
    showPOI = true,         -- Blizzard's map buttons in front of the titles
    showBars = true,        -- a thin bar under each counted objective
    showDoneObjectives = true,
    showItems = true,
    showRecipes = true,

    -- Instances and combat
    instanceCollapse = true,
    instanceOnlyHere = true,
    combatCollapse = false,
    fadeAlpha = 100,        -- percent, while the mouse is not over it

    -- Frame look
    borderStyle = "NONE",   -- NONE, FLAT or GOLD
    borderSize = 1,
    borderColor = { 0, 0, 0, 1 },
    cornerRadius = 10,
    shadowEnabled = true,
    shadowSize = 9,
    shadowAlpha = 65,       -- percent
    bgMode = "TEXTURE",     -- SOLID, GRADIENT or TEXTURE
    bgColor = { 0.216, 0.62, 0.718 },
    bgAlpha = 0,            -- percent
    bgTexture = "Blizzard Dialog Background Gold",
    headerLine = true,      -- the gold line under the header

    -- Text styles. Flags: "" none, OUTLINE, THICKOUTLINE, SHADOW.
    headerFont = "Friz Quadrata",
    headerSize = 18,
    headerFlag = "SHADOW",
    headerColor = { 1, 0.82, 0.29 },
    zoneFont = "Friz Quadrata",
    zoneSize = 14,
    zoneFlag = "",
    zoneColor = { 0.73, 0.64, 0.48 },
    titleFont = "Friz Quadrata",
    titleSize = 12,
    titleFlag = "SHADOW",
    titleColor = { 1, 0.82, 0 },
    objectiveFont = "Friz Quadrata",
    objectiveSize = 11,
    objectiveFlag = "",
    objectiveColor = { 0.84, 0.82, 0.78 },
    objectiveDoneColor = { 0.5, 0.54, 0.5 },
    doneFont = "Arial Narrow",
    doneSize = 13,
    doneFlag = "",
    doneColor = { 0.37, 0.83, 0.42 },

    -- Objective bars
    barHeight = 5,
    barTexture = "Blizzard",
    barColor = { 0.455, 1, 0.471 },
    barBgAlpha = 9,         -- percent

    -- Spacing
    padding = 10,           -- inside the frame
    questSpacing = 11,      -- between quests

    -- Minimap button
    minimapShow = true,
    minimapAngle = 200,
}

-- Slider ranges, used by the options window and to clamp typed values.
Settings.RANGES = {
    width = { 180, 800 },
    height = { 80, 1400 },
    scale = { 50, 200 },
    x = { -4000, 4000 },
    y = { -3000, 3000 },
    fadeAlpha = { 0, 100 },
    borderSize = { 1, 8 },
    cornerRadius = { 0, 12 },
    shadowSize = { 1, 24 },
    shadowAlpha = { 0, 100 },
    bgAlpha = { 0, 100 },
    headerSize = { 8, 30 },
    zoneSize = { 8, 30 },
    titleSize = { 8, 30 },
    objectiveSize = { 8, 30 },
    doneSize = { 8, 30 },
    barHeight = { 1, 12 },
    barBgAlpha = { 0, 100 },
    padding = { 0, 30 },
    questSpacing = { 0, 30 },
}

local listeners = {}

function Settings.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- key nil: everything may have changed (profile switch, reset).
function Settings.Changed(key)
    for _, fn in ipairs(listeners) do fn(key) end
end

function Settings.Get(key)
    local v = ns.DB()[key]
    if v == nil then v = Settings.DEFAULTS[key] end
    return v
end

-- A preset is read-only: changes last until the next reload. Said once.
local presetHintShown = false
local function presetHint()
    if presetHintShown or not ns.IsPreset or not ns.IsPreset(ns.ActiveProfile()) then return end
    presetHintShown = true
    if ns.Print then ns.Print(ns.L.MSG_PRESET_READONLY) end
end

local function sameValue(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for i = 1, math.max(#a, #b) do
        if a[i] ~= b[i] then return false end
    end
    return true
end

Settings.SameValue = sameValue

function Settings.Set(key, value)
    presetHint()
    local range = Settings.RANGES[key]
    if range and type(value) == "number" then
        value = math.max(range[1], math.min(range[2], math.floor(value + 0.5)))
    end
    if sameValue(value, Settings.DEFAULTS[key]) then value = nil end
    ns.DB()[key] = value
    Settings.Changed(key)
end

-- Several values in one go, one change for all (dragging writes position
-- and size together).
function Settings.SetMany(values)
    local db = ns.DB()
    for key, value in pairs(values) do
        local range = Settings.RANGES[key]
        if range and type(value) == "number" then
            value = math.max(range[1], math.min(range[2], math.floor(value + 0.5)))
        end
        if sameValue(value, Settings.DEFAULTS[key]) then value = nil end
        db[key] = value
    end
    Settings.Changed(nil)
end

-- A text style as one table: font, size, flag, color.
function Settings.TextStyle(name)
    return {
        font = Settings.Get(name .. "Font"),
        size = Settings.Get(name .. "Size"),
        flag = Settings.Get(name .. "Flag"),
        color = Settings.Get(name .. "Color"),
    }
end

-- Presets: ready-made looks, offered as read-only profiles (Profiles.lua):
-- the values here, everything else at its default.
Settings.PRESETS = {
    -- The look of the other Forever addons: gold frame, dark background,
    -- zones, Blizzard's order (the first defaults, as in the mockup).
    { id = "FOREVER", values = {
        groupByZone = true, sortBy = "WATCH", instanceOnlyHere = false,
        borderStyle = "GOLD", borderSize = 2, bgMode = "SOLID", bgColor = { 0.047, 0.047, 0.055 }, bgAlpha = 82,
        bgTexture = "Blizzard Dialog Background Dark",
        headerSize = 15, zoneSize = 11, titleFont = "Arial Narrow", titleSize = 14,
        objectiveFont = "Arial Narrow", objectiveSize = 13,
        barHeight = 3, barTexture = "Solid", barColor = { 1, 0.79, 0.19 }, barBgAlpha = 8,
        padding = 8, questSpacing = 6,
    } },
    -- The shipped defaults.
    { id = "DEFAULT", values = {} },
    -- Close to Blizzard's: no border, a faint background, no zones.
    { id = "MINIMAL", values = {
        borderStyle = "NONE", shadowEnabled = false, bgAlpha = 35, cornerRadius = 0,
        groupByZone = false, showBars = false, headerLine = false,
        titleFont = "Friz Quadrata", titleSize = 13, objectiveFont = "Friz Quadrata", objectiveSize = 12,
    } },
}

-- Back to the defaults (the language is not in the profile).
function Settings.ResetProfile()
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    Settings.Changed(nil)
end
