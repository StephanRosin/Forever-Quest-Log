-- Zone and instance names with their level range, the range coloured like Blizzard's
-- map labels: red/orange below the range, yellow inside, green from one
-- level under its top, grey far above (ZoneLevelData.lua has the ranges).
local _, ns = ...
local ZoneLevels = {}
ns.ZoneLevels = ZoneLevels

function ZoneLevels.Color(lo, hi, level)
    if level < lo then return GetQuestDifficultyColor(lo) end
    if level < hi - 1 then return QuestDifficultyColors.difficult end
    -- From top - 1 green (Stephan's rule; Blizzard's green starts 5 under),
    -- grey once Blizzard greys the top itself.
    local top = GetQuestDifficultyColor(hi)
    if top == QuestDifficultyColors.trivial then return top end
    return QuestDifficultyColors.standard
end

-- "Tanaris (40-50)", the range in its colour, or nil: unknown place or the option off.
function ZoneLevels.Label(name)
    local range = name and ns.Settings.Get("zoneLevels") and ns.ZoneLevelData[name]
    if not range then return nil end
    local lo, hi = range[1], range[2]
    local c = ZoneLevels.Color(lo, hi, UnitLevel("player"))
    local span = lo == hi and tostring(lo) or (lo .. "-" .. hi)
    return ("%s |cff%02x%02x%02x(%s)|r"):format(name, c.r * 255, c.g * 255, c.b * 255, span)
end
