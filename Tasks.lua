local ADDON, ns = ...
local Settings = ns.Settings
local S = Settings.Get

-- The player's own task lists, shown above the quests: per character, each a
-- name and entries, either an item with an amount (counted from the bags) or
-- a line of text ticked by hand. TaskUI.lua is the window and the menus.
local Tasks = {}
ns.Tasks = Tasks

Tasks.MIN_SEARCH = 3    -- letters before anything is suggested
Tasks.MAX_RESULTS = 8

local function changed()
    if ns.Tracker then ns.Tracker.Refresh() end
    if ns.Notes then ns.Notes.Layout() end
end

function Tasks.Lists()
    ns.CharState()  -- creates ForeverQuestLogChar
    ForeverQuestLogChar.taskLists = ForeverQuestLogChar.taskLists or {}
    return ForeverQuestLogChar.taskLists
end

local function trim(text) return (text or ""):match("^%s*(.-)%s*$") end

-- Lists ---------------------------------------------------------------------

-- Returns the new list, nil for an empty name.
function Tasks.AddList(name)
    name = trim(name)
    if name == "" then return nil end
    local list = { name = name, entries = {} }
    table.insert(Tasks.Lists(), list)
    changed()
    return list
end

function Tasks.RenameList(list, name)
    name = trim(name)
    if name == "" then return false end
    list.name = name
    changed()
    return true
end

local function removeFrom(items, item)
    for i, candidate in ipairs(items) do
        if candidate == item then
            table.remove(items, i)
            return
        end
    end
end

-- Puts item in front of `before` (nil: at the end). False when nothing moves.
local function moveBefore(items, item, before)
    if item == before then return false end
    removeFrom(items, item)
    local at = #items + 1
    for i, candidate in ipairs(items) do
        if candidate == before then at = i break end
    end
    table.insert(items, at, item)
    changed()
    return true
end

function Tasks.MoveList(list, before) return moveBefore(Tasks.Lists(), list, before) end
function Tasks.MoveEntry(list, entry, before) return moveBefore(list.entries, entry, before) end

function Tasks.RemoveList(list)
    removeFrom(Tasks.Lists(), list)
    changed()
end

-- Undocked: a window of its own (Notes.lua) instead of a part of the tracker.
function Tasks.Undock(list)
    list.undocked = true
    list.note = list.note or { x = math.floor(UIParent:GetWidth() / 2 - 120), y = -200, w = 240, h = 200 }
    changed()
end

function Tasks.Dock(list)
    list.undocked = nil
    changed()
end

function Tasks.ToggleList(list)
    list.collapsed = not list.collapsed or nil
    changed()
end

-- Entries -------------------------------------------------------------------

local function validAmount(amount)
    return math.max(1, math.floor(tonumber(amount) or 1))
end

-- An item already on the list gets the new amount instead of a second line.
function Tasks.AddItem(list, item, amount)
    for _, entry in ipairs(list.entries) do
        if entry.itemID == item.id then
            entry.goal = validAmount(amount)
            changed()
            return
        end
    end
    table.insert(list.entries, { itemID = item.id, name = item.name, goal = validAmount(amount) })
    changed()
end

-- A zone, dungeon or raid picked from the suggestions, kept while its name
-- is in the text: the row shows its symbol, a zone opens on the map.
local function placeIn(text, place)
    if place and text:find(place.name, 1, true) then
        return { kind = place.kind, name = place.name, mapID = place.mapID }
    end
end

function Tasks.AddText(list, text, place)
    text = trim(text)
    if text == "" then return false end
    table.insert(list.entries, { text = text, place = placeIn(text, place) })
    changed()
    return true
end

function Tasks.RemoveEntry(list, entry)
    removeFrom(list.entries, entry)
    changed()
end

function Tasks.SetAmount(entry, amount)
    local n = tonumber(amount)
    if not n or n < 1 then return false end
    entry.goal = validAmount(n)
    changed()
    return true
end

-- place: a new pick, else the entry keeps its own while the name stays.
function Tasks.SetText(entry, text, place)
    text = trim(text)
    if text == "" then return false end
    entry.text = text
    entry.place = placeIn(text, place) or placeIn(text, entry.place)
    changed()
    return true
end

Tasks.PLACE_SYMBOL = {
    zone = "|TInterface\\Icons\\INV_Misc_Map_01:0|t",
    dungeon = "|A:Dungeon:14:14|a",
    raid = "|A:Raid:14:14|a",
}

-- Items tick themselves when the amount is there.
function Tasks.Toggle(entry)
    if entry.itemID then return end
    entry.done = not entry.done or nil
    changed()
end

-- What the row shows; the fields are those of an objective line (Rows.lua).
function Tasks.Line(entry)
    local line
    if entry.itemID then
        local have = C_Item.GetItemCount(entry.itemID, S("taskCountBank"))
        -- The client's name when it has one: the shipped list is English in
        -- languages the addon has no names for.
        line = { text = C_Item.GetItemNameByID(entry.itemID) or entry.name,
            cur = have, max = entry.goal, done = have >= entry.goal }
    else
        local symbol = entry.place and Tasks.PLACE_SYMBOL[entry.place.kind]
        line = { text = symbol and (symbol .. " " .. entry.text) or entry.text, done = entry.done and true or false }
    end
    line.check = true
    line.icon = line.done and "BoxChecked" or "Box"
    return line
end

function Tasks.RemoveDone(list)
    for i = #list.entries, 1, -1 do
        if Tasks.Line(list.entries[i]).done then table.remove(list.entries, i) end
    end
    changed()
end

-- The rows of all lists, for the tracker.
function Tasks.Entries()
    local rows = {}
    for _, list in ipairs(Tasks.Lists()) do
        if not list.undocked then
            local head = { kind = "list", list = list, name = list.name, collapsed = list.collapsed and true or false }
            rows[#rows + 1] = head
            local done = 0
            for _, entry in ipairs(list.entries) do
                local line = Tasks.Line(entry)
                if line.done then done = done + 1 end
                if not list.collapsed then rows[#rows + 1] = { kind = "task", list = list, task = entry, line = line } end
            end
            head.count = done .. "/" .. #list.entries
        end
    end
    return rows
end

-- Item names ----------------------------------------------------------------

-- ASCII plus the capitals of Latin-1 (Ä, É, Ñ), which string.lower leaves
-- alone and which two letters of a name often start with.
local function lower(text)
    return (text:lower():gsub("\195([\128-\158])", function(c) return "\195" .. string.char(c:byte() + 32) end))
end

-- Built on the first search: most sessions never need it.
local index
local function items()
    if not index then
        index = {}
        for id, quality, name in ns.ItemNames:gmatch("(%d+)\t(%d)\t([^\n]+)") do
            index[#index + 1] = { id = tonumber(id), quality = tonumber(quality), name = name, lower = lower(name) }
        end
    end
    return index
end

local function letterCount(text) return select(2, text:gsub("[^\128-\191]", "")) end

-- Zone names ----------------------------------------------------------------

-- shortcut: scans map ids 1..MAX_MAP_ID; raise it if Forever adds maps beyond.
Tasks.MAX_MAP_ID = 3000

-- The client's zones in its own language, built on the first search, and
-- the shipped dungeons and raids (PlaceNames.lua: the client knows none).
-- Each: { zone = true, kind = "zone" | "dungeon" | "raid", name, mapID }.
local zoneIndex
local function zones()
    if not zoneIndex then
        zoneIndex = {}
        local seen = {}
        local function add(kind, name, mapID)
            if name and name ~= "" and not seen[name] then
                seen[name] = true
                zoneIndex[#zoneIndex + 1] = { zone = true, kind = kind, name = name, mapID = mapID, lower = lower(name) }
            end
        end
        for id = 1, Tasks.MAX_MAP_ID do
            local info = C_Map.GetMapInfo(id)
            if info and info.mapType == Enum.UIMapType.Zone then add("zone", info.name, id) end
        end
        local places = ns.PlaceNames or {}
        for _, name in ipairs(places.raids or {}) do add("raid", name) end
        for _, name in ipairs(places.dungeons or {}) do add("dungeon", name) end
        table.sort(zoneIndex, function(a, b) return a.lower < b.lower end)
    end
    return zoneIndex
end

-- Zones starting with the end of the text ("Quests in Tan" -> Tanaris), so a
-- zone can go into a sentence. `from` is where the replaced part begins.
local function searchZones(text)
    local found, seen = {}, {}
    local from = 1
    while from do
        local tail = lower(text:sub(from))
        if letterCount(tail) >= Tasks.MIN_SEARCH then
            for _, zone in ipairs(zones()) do
                -- Any word of the name: "Todesm" finds "Die Todesminen".
                if not seen[zone] and (zone.lower:sub(1, #tail) == tail or zone.lower:find(" " .. tail, 1, true)) then
                    seen[zone] = true
                    found[#found + 1] = { zone = true, kind = zone.kind, name = zone.name, mapID = zone.mapID, from = from }
                    if #found == Tasks.MAX_RESULTS then return found end
                end
            end
        end
        from = text:find("%s%S", from)
        from = from and from + 1
    end
    return found
end

function Tasks.SearchZones(text) return searchZones(trim(text)) end

-- Zones first (few, matching the end of the text), then items whose name
-- contains the text: those starting with it first, each group alphabetical
-- (the shipped order).
function Tasks.Search(text)
    local starts = searchZones(trim(text))
    local query = lower(trim(text))
    if letterCount(query) < Tasks.MIN_SEARCH then return starts end
    if #starts == Tasks.MAX_RESULTS then return starts end
    local contains = {}
    for _, item in ipairs(items()) do
        local at = item.lower:find(query, 1, true)
        if at == 1 then
            starts[#starts + 1] = item
            if #starts == Tasks.MAX_RESULTS then return starts end
        elseif at and #contains < Tasks.MAX_RESULTS then
            contains[#contains + 1] = item
        end
    end
    for _, item in ipairs(contains) do
        if #starts == Tasks.MAX_RESULTS then break end
        starts[#starts + 1] = item
    end
    return starts
end

-- The item called exactly this; typed in full it needs no click.
function Tasks.FindExact(text)
    local query = lower(trim(text))
    for _, item in ipairs(items()) do
        if item.lower == query then return item end
    end
end
