local ADDON, ns = ...
local Settings = ns.Settings
local S = Settings.Get

-- The player's own task lists, shown above the quests: per character, each a
-- name and entries: an item with an amount (counted from the bags), a goal
-- the game counts (level, gold), a quest (done once turned in) or a line of
-- text ticked by hand. TaskUI.lua is the window and the menus.
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

-- Level and gold: what the player has now, for an entry { goalKind, goal }.
Tasks.GOALS = {
    level = function() return UnitLevel("player") end,
    money = function() return math.floor(GetMoney() / 10000) end,
}

-- Like an item: the same goal again changes the amount.
function Tasks.AddGoal(list, kind, amount)
    for _, entry in ipairs(list.entries) do
        if entry.goalKind == kind then
            entry.goal = validAmount(amount)
            changed()
            return
        end
    end
    table.insert(list.entries, { goalKind = kind, goal = validAmount(amount) })
    changed()
end

-- The level as the tracker shows it, while the quest is in the log.
local function questLevel(questID)
    local level = C_QuestLog.GetQuestDifficultyLevel and C_QuestLog.GetQuestDifficultyLevel(questID)
    if level and level > 0 then return level end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIndex and C_QuestLog.GetInfo(logIndex)
    return info and info.level and info.level > 0 and info.level or nil
end

-- Title and level are kept for when the client no longer knows the quest.
function Tasks.AddQuest(list, questID, title)
    for _, entry in ipairs(list.entries) do
        if entry.questID == questID then return end
    end
    table.insert(list.entries, { questID = questID, text = title, level = questLevel(questID) })
    changed()
end

-- The quest giver's "!" while running, "?" once ready to turn in. Not the
-- tracker's symbols: without their round badge those are a few dots. These
-- fill nearly all their height, so they need no cut.
Tasks.QUEST_SYMBOL = {
    progress = "|A:QuestNormal:14:14|a",
    complete = "|A:QuestTurnin:14:14|a",
}

local function questDone(questID)
    local flagged = C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
    return flagged and flagged(questID) and true or false
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

-- What each place shows: file and tex coords (0..1). The map legend's
-- Dungeon/Raid atlases are mostly glow; the ring spans texels 9-41 of 50, so
-- they are cut to that like the map icon to its picture, and all look as wide.
-- Their spot in the file comes from the client: Forever packs it elsewhere.
local RING_FROM, RING_TO = 9 / 50, 41 / 50
Tasks.PLACE_TEXTURE = { zone = { "Interface\\Icons\\INV_Misc_Map_01", 5 / 64, 59 / 64, 5 / 64, 59 / 64 } }
Tasks.PLACE_SYMBOL = {}
for kind, atlas in pairs({ dungeon = "Dungeon", raid = "Raid" }) do
    local a = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if a then
        local w, h = a.rightTexCoord - a.leftTexCoord, a.bottomTexCoord - a.topTexCoord
        Tasks.PLACE_TEXTURE[kind] = { a.file,
            a.leftTexCoord + w * RING_FROM, a.leftTexCoord + w * RING_TO,
            a.topTexCoord + h * RING_FROM, a.topTexCoord + h * RING_TO }
    else
        Tasks.PLACE_SYMBOL[kind] = "|A:" .. atlas .. ":14:14|a"
    end
end
-- Markup takes texel coords; on a scale of 10000 the fractions stay exact enough.
for kind, t in pairs(Tasks.PLACE_TEXTURE) do
    local c = function(f) return math.floor(f * 10000 + 0.5) end
    Tasks.PLACE_SYMBOL[kind] = ("|T%s:14:14:0:0:10000:10000:%d:%d:%d:%d|t"):format(t[1], c(t[2]), c(t[3]), c(t[4]), c(t[5]))
end

-- Items, goals and quests tick themselves.
function Tasks.Toggle(entry)
    if entry.itemID or entry.goalKind or entry.questID then return end
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
    elseif entry.goalKind then
        local have = Tasks.GOALS[entry.goalKind]()
        line = { text = ns.L["TASK_GOAL_" .. entry.goalKind:upper()]:format(entry.goal),
            cur = have, max = entry.goal, done = have >= entry.goal }
    elseif entry.questID then
        local id = entry.questID
        local done = questDone(id)
        local ready = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
        local text = (ready and Tasks.QUEST_SYMBOL.complete or Tasks.QUEST_SYMBOL.progress) .. " "
            .. (C_QuestLog.GetTitleForQuestID(id) or entry.text or "")
        -- "(46)" in the tracker's difficulty colour; gone once turned in, like a zone's range.
        local level = not done and (questLevel(id) or entry.level)
        if level then
            local c = GetQuestDifficultyColor(level)
            text = text .. (" |cff%02x%02x%02x(%d)|r"):format(c.r * 255, c.g * 255, c.b * 255, level)
        end
        line = { text = text, done = done }
    else
        local place = entry.place
        local symbol = place and Tasks.PLACE_SYMBOL[place.kind]
        local text = entry.text
        local label = place and not entry.done and ns.ZoneLevels.Label(place.name)
        if label then
            local at = text:find(place.name, 1, true)
            if at then text = text:sub(1, at - 1) .. label .. text:sub(at + #place.name) end
        end
        line = { text = symbol and (symbol .. " " .. text) or text, done = entry.done and true or false }
        -- Where the player is now: coloured like a quest title.
        if place and not entry.done and Tasks.IsHere(place.name) then line.color = S("titleColor") end
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

-- In a dungeon the zone text is the instance's name, as in PlaceNames.lua.
function Tasks.IsHere(name)
    local here = GetRealZoneText and GetRealZoneText()
    return here ~= nil and here ~= "" and lower(here) == lower(name)
end

-- Goals ---------------------------------------------------------------------

-- The word for level or gold alone ("Gold": the amount comes from the box
-- on the right) or with a number ("Level 50", "100 gold", "100g") suggests
-- the goal; Enter without picking it keeps a plain text.
local function hasWord(text, words)
    for word in words:gmatch("%S+") do
        if (" " .. text .. " "):find("[^%a]" .. word .. "[^%a]") then return true end
    end
end

local function isWord(text, words)
    for word in words:gmatch("%S+") do
        if text == word then return true end
    end
end

local function searchGoals(text)
    local t, L, found = lower(text), ns.L, {}
    local n = tonumber(t:match("%d+"))
    if n and n < 1 then return found end
    local kinds = {
        { "level", L.TASK_WORDS_LEVEL .. " level lvl", L.TASK_GOAL_LEVEL, L.TASK_GOAL_LEVEL_AMOUNT },
        { "money", L.TASK_WORDS_GOLD .. " gold", L.TASK_GOAL_MONEY, L.TASK_GOAL_MONEY_AMOUNT },
    }
    for _, k in ipairs(kinds) do
        local kind, words = k[1], k[2]
        if n and (hasWord(t, words) or (kind == "money" and t:find("%d%s*g$"))) then
            found[#found + 1] = { goal = kind, amount = n, name = k[3]:format(n) }
        elseif not n and isWord(t, words) then
            found[#found + 1] = { goal = kind, name = k[4] }
        end
    end
    return found
end

-- Goals first (at most two), then zones (few, matching the end of the text), then items whose name
-- contains the text: those starting with it first, each group alphabetical
-- (the shipped order).
function Tasks.Search(text)
    local starts = searchGoals(trim(text))
    for _, zone in ipairs(searchZones(trim(text))) do
        if #starts == Tasks.MAX_RESULTS then return starts end
        starts[#starts + 1] = zone
    end
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
