local _, ns = ...

-- English is the base language and always loads first. Every other language
-- (Locales/<code>.lua) fills a table of its own; Locale.lua picks one. ns.L
-- holds no strings itself: it looks a key up in the chosen language, then in
-- English, and a key missing from both comes back as it is, so a missing
-- string shows in the game instead of raising an error.
local L = {}
ns.Locales = { enUS = L }

local active = L
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = active[key]
        if v == nil then v = L[key] end
        if v == nil then return key end
        return v
    end,
    __newindex = function() error("ns.L is read-only; add strings to Locales/*.lua") end,
})

-- Locale.lua only: shows the given language's table through ns.L.
function ns.SetActiveLocale(code)
    active = ns.Locales[code] or L
end

L.ADDON_NAME = "Forever Quest Log"

-- The tracker
L.HEADER_QUESTS = "Quests"
L.SECTION_RECIPES = "Professions"
L.ZONE_OTHER = "Other"
L.EMPTY = "No tracked quests. Shift-click a quest in the quest log to track it."
L.LOADING = "Loading..."
L.READY_FOR_TURN_IN = "Ready for turn-in"
L.QUEST_COMPLETE = "Quest complete"
L.CLICK_TO_COMPLETE = "Click to complete"
L.FAILED = "Failed"
L.CHIP_THIS_DUNGEON = "This dungeon"
L.CHIP_ALL_QUESTS = "All quests"
L.UNLOCKED_HINT = "drag the header to move, the corner to resize"

-- Header buttons
L.TIP_COLLAPSE = "Collapse"
L.TIP_EXPAND = "Expand"
L.TIP_OPTIONS = "Options"
L.TIP_LOCK = "Lock the frame"
L.TIP_UNLOCK = "Unlock the frame to move and resize it (Ctrl + drag moves it while locked)"
L.TIP_SORT_WATCH = "Sorted like Blizzard's tracker (nearest first). Click: sort by level"
L.TIP_SORT_LEVEL = "Sorted by level. Click: sort like Blizzard's tracker"
L.TIP_ZONES_ON = "Grouped by zone. Click: one list"
L.TIP_ZONES_OFF = "One list. Click: group by zone"
L.TIP_ONLY_HERE = "Show only this dungeon's quests, or all tracked quests"
L.TIP_RESIZE = "Drag to resize"
L.TIP_COUNT = "%d of %d quests in the quest log"
L.TIP_TRACKED = "%d of them tracked"

-- Chat
L.MSG_LOCKED = "Tracker locked."
L.MSG_UNLOCKED = "Tracker unlocked: drag the header to move it, the corner to resize it."
L.MSG_USAGE = "/fql (options), /fql lock, /fql unlock, /fql reset (position and size), /fql status"
L.MSG_POSITION_RESET = "Position and size reset."
L.MSG_LAST_PROFILE = "The last profile cannot be deleted."
L.MSG_PRESET_READONLY = "This is a preset: changes last until the next reload. Use \"Save as...\" to keep them in a profile of your own."
L.MSG_PRESET_NO_DELETE = "Presets cannot be deleted."
L.MSG_IMPORTED = "Profile imported."
L.MSG_IMPORT_FAILED = "That is not a Forever Quest Log profile string."
L.STATUS_CLIENT = "client"
L.STATUS_BLIZZARD = "Blizzard's tracker"
L.STATUS_HIDDEN = "hidden"
L.STATUS_VISIBLE = "visible"
L.STATUS_USING_BLIZZARD = "Blizzard's tracker is in use (General -> Use Blizzard's tracker)."
L.STATUS_WATCHED = "Tracked quests"
L.STATUS_ITEMS = "item buttons"
L.STATUS_PENDING = "A layout waits for the end of combat."

-- Minimap button
L.MINIMAP_LEFT_CLICK = "Left-click: options"
L.MINIMAP_RIGHT_CLICK = "Right-click: lock or unlock the tracker"
L.MINIMAP_DRAG = "Drag: move this button"
L.OPEN_OPTIONS = "Open the options"

-- Options window
L.OPT_LANGUAGE = "Language"
L.LANGUAGE_AUTO = "Game language"
L.INHERITED = "(inherited)"
L.RESET_OVERRIDE = "Reset"
L.OPT_UNLOCK_FRAME = "Unlock the tracker"
L.OPT_LOCK_FRAME = "Lock the tracker"
L.PAGE_GENERAL = "General"
L.PAGE_LAYOUT = "Layout"
L.PAGE_APPEARANCE = "Appearance"
L.PAGE_TEXT = "Text"
L.PAGE_BARS = "Bars"
L.PAGE_INSTANCES = "Instances"
L.PAGE_PROFILES = "Profiles"

L.OPT_LIST = "List"
L.OPT_GROUP_BY_ZONE = "Group by zone"
L.OPT_CURRENT_ZONE_FIRST = "Current zone first"
L.OPT_SORT_BY = "Sort"
L.SORT_WATCH = "Like Blizzard (nearest first)"
L.SORT_LEVEL = "By level"
L.OPT_SHOW = "Show"
L.OPT_SHOW_LEVEL = "Quest level"
L.OPT_LEVEL_COLORS = "Level in difficulty colours"
L.OPT_SHOW_TAGS = "Tags (Elite, Dungeon, ...)"
L.OPT_SHOW_POI = "Map buttons"
L.OPT_SHOW_DONE = "Finished objectives"
L.OPT_SHOW_ITEMS = "Quest item buttons"
L.OPT_SHOW_RECIPES = "Tracked recipes"
L.OPT_MINIMAP = "Minimap"
L.OPT_MINIMAP_SHOW = "Minimap button"
L.OPT_BLIZZARD = "Blizzard's tracker"
L.OPT_BLIZZARD_HINT = "Switches this tracker off and gives Blizzard's back. Takes effect after /reload."
L.OPT_USE_BLIZZARD = "Use Blizzard's tracker"

L.OPT_POSITION = "Position and size"
L.OPT_LOCK = "Locked"
L.OPT_MOVE_HINT = "Unlocked: drag the header to move, the corner to resize. Ctrl + drag moves it while locked."
L.OPT_WIDTH = "Width"
L.OPT_HEIGHT = "Maximum height"
L.OPT_FIT_CONTENT = "Shrink to the content"
L.OPT_GROW = "Grows"
L.GROW_DOWN = "Down (top edge fixed)"
L.GROW_UP = "Up (bottom edge fixed)"
L.OPT_SCALE = "Scale"
L.OPT_SNAP_MINIMAP = "Below the minimap"
L.OPT_RESET_POSITION = "Reset position"
L.OPT_SPACING = "Spacing"
L.OPT_PADDING = "Inner margin"
L.OPT_QUEST_SPACING = "Between quests"
L.OPT_FADE = "Fading"
L.OPT_FADE_ALPHA = "Opacity without the mouse over it"

L.OPT_BACKGROUND = "Background"
L.OPT_BG_MODE = "Kind"
L.BG_SOLID = "Solid"
L.BG_GRADIENT = "Gradient"
L.BG_TEXTURE = "Texture"
L.OPT_BG_COLOR = "Colour"
L.OPT_BG_TEXTURE = "Texture"
L.OPT_BG_ALPHA = "Opacity"
L.OPT_HEADER_LINE = "Line under the header"
L.OPT_BORDER = "Border"
L.OPT_BORDER_STYLE = "Style"
L.BORDER_GOLD = "Gold"
L.BORDER_FLAT = "Flat"
L.BORDER_NONE = "None"
L.OPT_BORDER_SIZE = "Thickness"
L.OPT_BORDER_COLOR = "Colour (flat)"
L.OPT_CORNER_RADIUS = "Corner radius"
L.OPT_SHADOW = "Shadow"
L.OPT_SHADOW_SHOW = "Drop shadow"
L.OPT_SHADOW_SIZE = "Size"
L.OPT_SHADOW_ALPHA = "Strength"

L.STYLE_HEADER = "Header"
L.STYLE_ZONE = "Zones"
L.STYLE_TITLE = "Quest titles"
L.STYLE_OBJECTIVE = "Objectives"
L.STYLE_DONE = "Turn-in"
L.OPT_FONT = "Font"
L.OPT_FONT_SIZE = "Size"
L.OPT_OUTLINE = "Outline"
L.OUTLINE_NONE = "None"
L.OUTLINE_SHADOW = "Shadow"
L.OUTLINE_NORMAL = "Outline"
L.OUTLINE_THICK = "Thick outline"
L.OPT_COLOR = "Colour"
L.OPT_DONE_OBJECTIVE_COLOR = "Finished objectives"

L.OPT_BARS = "Objective bars"
L.OPT_SHOW_BARS = "A bar under counted objectives"
L.OPT_BAR_HEIGHT = "Height"
L.OPT_BAR_TEXTURE = "Texture"
L.OPT_BAR_COLOR = "Colour"
L.OPT_BAR_BG_ALPHA = "Empty part"

L.OPT_INSTANCES = "Dungeons and raids"
L.OPT_INSTANCE_COLLAPSE = "Collapse on entering"
L.OPT_INSTANCE_ONLY_HERE = "Only this dungeon's quests"
L.OPT_INSTANCE_HINT = "One click on the arrow opens it again. The chip in the header switches between this dungeon's quests and all of them."
L.OPT_COMBAT = "Combat"
L.OPT_COMBAT_COLLAPSE = "Collapse in combat"
L.OPT_COMBAT_HINT = "Quest item buttons cannot move in combat: while they show, the list waits for the end of combat to change."

L.OPT_PROFILES = "Profiles"
L.OPT_PROFILE_ACTIVE = "Active profile"
L.OPT_PROFILE_SAVE_AS = "Save as..."
L.OPT_PROFILE_DELETE = "Delete"
L.POPUP_PROFILE_NAME = "Name of the new profile:"
L.POPUP_PROFILE_DELETE = "Delete the profile \"%s\"?"
L.PRESET_SUFFIX = "(preset)"
L.PRESET_FOREVER = "Forever"
L.PRESET_MINIMAL = "Minimal"
L.PRESET_DEFAULT = "Shipped"
L.OPT_SHARE = "Share"
L.OPT_SHARE_HINT = "Export copies the active profile as a string; paste a string and click Import to take it over."
L.OPT_EXPORT = "Export"
L.OPT_IMPORT = "Import"
L.OPT_RESET = "Reset"
L.OPT_RESET_HINT = "Back to the defaults for the active profile."
L.OPT_RESET_BUTTON = "Reset the profile"

-- World map
L.PAGE_MAP = "World map"
L.OPT_MAP_POSITION = "Position"
L.OPT_MAP_MOVE = "Drag the world map by its title bar"
L.OPT_MAP_MOVE_HINT = "Blizzard's map stays as it is; it only opens where you left it. The maximized map is not moved."
L.OPT_MAP_RESET = "Back to Blizzard's place"
L.OPT_MAP_LOOK = "Frame"
L.OPT_MAP_STYLE = "Style"
L.MAPSTYLE_BLIZZARD = "Blizzard's"
L.MAPSTYLE_TRACKER = "Like the tracker"
L.MAPSTYLE_OWN = "Own settings"
L.TIP_MAP_DRAG = "Drag to move the map"

-- Quest log in the world map
L.OPT_LOG_LOOK = "Quest list in the world map"
L.OPT_LOG_STYLE = "Style"
L.OPT_LOG_HINT = "Background and fonts of the list; colours, rows and clicks stay Blizzard's. Takes effect when the list updates (opening the map)."
L.LOGSTYLE_HEADER = "Zone headers"
L.LOGSTYLE_TITLE = "Quest titles"
L.LOGSTYLE_OBJECTIVE = "Objectives"

-- Selected quest tracker
L.FOCUS_EMPTY = "No quest focused. Click a quest's map button, or \"Focus\" in its menu."
L.PAGE_FOCUS = "Focused quest"
L.OPT_FOCUS = "Selected quest tracker"
L.OPT_FOCUS_ENABLED = "Show the focused quest in a frame of its own"
L.OPT_FOCUS_HINT = "The quest you focus (its map button, or “Focus” in its menu) with title and progress. Unlock it to drag it anywhere and to widen it at its corner."
L.OPT_FOCUS_FALLBACK = "Nothing focused"
L.FALLBACK_NONE = "Hide the frame"
L.FALLBACK_FIRST = "Show the first tracked quest"
L.OPT_FOCUS_HIDE_COMBAT = "Hide in combat"
L.OPT_FOCUS_ALPHA = "Opacity"
L.OPT_MAP_PORTRAIT = "Show the portrait"
L.OPT_MAP_BACKGROUND = "Frame background"
L.OPT_MAP_TITLE = "Title"
