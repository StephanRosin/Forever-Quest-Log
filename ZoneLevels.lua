-- Zone and instance names with their level range, the range coloured by Stephan's rule:
-- red below, orange in the first two levels, yellow inside, green in the last tenth,
-- grey above (ZoneLevelData.lua has the ranges).
local _, ns = ...
local ZoneLevels = {}
ns.ZoneLevels = ZoneLevels

function ZoneLevels.Color(lo, hi, level)
    local c = QuestDifficultyColors
    if level < lo then return c.impossible end
    if level > hi then return c.trivial end
    if level <= lo + 1 then return c.verydifficult end
    if level >= hi - (hi - lo) * 0.1 then return c.standard end
    return c.difficult
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
