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

function Tasks.RemoveList(list)
    removeFrom(Tasks.Lists(), list)
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

function Tasks.AddText(list, text)
    text = trim(text)
    if text == "" then return false end
    table.insert(list.entries, { text = text })
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

function Tasks.SetText(entry, text)
    text = trim(text)
    if text == "" then return false end
    entry.text = text
    changed()
    return true
end

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
        line = { text = entry.text, done = entry.done and true or false }
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

-- Items whose name contains the text: those starting with it first, each
-- group alphabetical (the shipped order).
function Tasks.Search(text)
    local query = lower(trim(text))
    if letterCount(query) < Tasks.MIN_SEARCH then return {} end
    local starts, contains = {}, {}
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
