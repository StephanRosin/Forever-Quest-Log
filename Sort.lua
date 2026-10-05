local ADDON, ns = ...
local L = ns.L

-- Orders the quests and groups them for drawing. Pure: no frames, no game
-- calls, so the tests check it directly.
--
--   Sort.Build(quests, opts) -> list of entries
--     { kind = "zone", name, count, collapsed }
--     { kind = "quest", quest }
--
-- opts: sortBy ("WATCH" | "LEVEL"), groupByZone, currentZoneFirst,
-- currentZone (the player's zone name), collapsedZones (name -> true),
-- onlyZone (an instance name: only quests under that header).
local Sort = {}
ns.Sort = Sort

local function lower(s) return type(s) == "string" and s:lower() or "" end

-- Blizzard's order is the watch order (sorted by proximity on zone change);
-- LEVEL puts low levels first, the watch order breaking ties.
local function compare(sortBy)
    if sortBy == "LEVEL" then
        return function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            return a.watchIndex < b.watchIndex
        end
    end
    return function(a, b) return a.watchIndex < b.watchIndex end
end

function Sort.ZoneName(quest)
    return quest.zone or L.ZONE_OTHER
end

-- Only the quests under the header named like the instance.
function Sort.Filter(quests, onlyZone)
    if not onlyZone or onlyZone == "" then return quests end
    local wanted, kept = lower(onlyZone), {}
    for _, q in ipairs(quests) do
        if lower(q.zone) == wanted then kept[#kept + 1] = q end
    end
    return kept
end

function Sort.Build(quests, opts)
    opts = opts or {}
    local list = {}
    for _, q in ipairs(Sort.Filter(quests, opts.onlyZone)) do list[#list + 1] = q end
    table.sort(list, compare(opts.sortBy))

    local entries = {}
    if not opts.groupByZone then
        for _, q in ipairs(list) do entries[#entries + 1] = { kind = "quest", quest = q } end
        return entries
    end

    -- Zones in the order of their first quest in the sorted list: by watch
    -- order the nearest zone comes first, by level the zone with the lowest
    -- quest. The player's own zone can go to the top.
    local zones, byName = {}, {}
    for _, q in ipairs(list) do
        local name = Sort.ZoneName(q)
        local zone = byName[name]
        if not zone then
            zone = { name = name, quests = {}, rank = #zones + 1 }
            byName[name] = zone
            zones[#zones + 1] = zone
        end
        zone.quests[#zone.quests + 1] = q
    end
    if opts.currentZoneFirst and opts.currentZone then
        local here = lower(opts.currentZone)
        table.sort(zones, function(a, b)
            local ah, bh = lower(a.name) == here, lower(b.name) == here
            if ah ~= bh then return ah end
            return a.rank < b.rank
        end)
    end
    local collapsed = opts.collapsedZones or {}
    for _, zone in ipairs(zones) do
        local isCollapsed = collapsed[zone.name] and true or false
        entries[#entries + 1] = { kind = "zone", name = zone.name, count = #zone.quests, collapsed = isCollapsed }
        if not isCollapsed then
            for _, q in ipairs(zone.quests) do entries[#entries + 1] = { kind = "quest", quest = q } end
        end
    end
    return entries
end
