local ADDON, ns = ...
local L = ns.L

-- Quests the player abandoned, per character, so they can be found again
-- (wish from CurseForge, GalvinW). Not in the tracker list: they have their
-- own page in the options window.
--
-- Every way to abandon in Forever (quest log, map, tracker menus) ends in
-- Blizzard's popup: C_QuestLog.SetAbandonQuest() picks the quest, the popup's
-- OnAccept calls C_QuestLog.AbandonQuest(). Hooks on C_* tables are harmless
-- in Forever (unlike on frames). The quest is read when it is picked, while it
-- is surely still in the log; QUEST_REMOVED alone could not tell an abandoned
-- quest from a turned-in one.
local Abandoned = {}
ns.Abandoned = Abandoned

Abandoned.MAX = 30  -- the oldest drop out; a menu longer than this is no help

-- Where each quest in the log was picked up (only those accepted since this
-- addon version): questID -> { mapID, x, y }.
local function pickups()
    ns.CharState()  -- creates ForeverQuestLogChar
    ForeverQuestLogChar.pickups = ForeverQuestLogChar.pickups or {}
    return ForeverQuestLogChar.pickups
end

-- Newest first: { id, title, level, zone, mapID, x, y }.
function Abandoned.List()
    ns.CharState()
    ForeverQuestLogChar.abandoned = ForeverQuestLogChar.abandoned or {}
    return ForeverQuestLogChar.abandoned
end

function Abandoned.Remove(questID)
    local list = Abandoned.List()
    for i = #list, 1, -1 do
        if list[i].id == questID then table.remove(list, i) end
    end
end

function Abandoned.Clear()
    ForeverQuestLogChar.abandoned = {}
end

function Abandoned.Add(entry)
    Abandoned.Remove(entry.id)
    local list = Abandoned.List()
    table.insert(list, 1, entry)
    while #list > Abandoned.MAX do table.remove(list) end
end

-- The quest as it is in the log now, with its pickup point if known.
local function snapshot(questID)
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIndex and C_QuestLog.GetInfo(logIndex)
    if not info or info.isHeader then return nil end
    local at = pickups()[questID] or {}
    return {
        id = questID,
        title = info.title or C_QuestLog.GetTitleForQuestID(questID) or "",
        level = (C_QuestLog.GetQuestDifficultyLevel and C_QuestLog.GetQuestDifficultyLevel(questID)) or info.level,
        zone = ns.Data.QuestHeaders()[questID],
        mapID = at.mapID, x = at.x, y = at.y,
    }
end

local picked
if C_QuestLog.SetAbandonQuest and C_QuestLog.AbandonQuest then
    hooksecurefunc(C_QuestLog, "SetAbandonQuest", function()
        local questID = C_QuestLog.GetAbandonQuest and C_QuestLog.GetAbandonQuest()
        picked = questID and questID ~= 0 and snapshot(questID) or nil
    end)
    hooksecurefunc(C_QuestLog, "AbandonQuest", function()
        if picked then Abandoned.Add(picked) end
        picked = nil
    end)
end

-- The player's spot when a quest is accepted. Taking it again takes it off
-- the list.
ns.On("QUEST_ACCEPTED", function(_, questID)
    Abandoned.Remove(questID)
    local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        local x, y = pos:GetXY()
        pickups()[questID] = { mapID = mapID, x = x, y = y }
    end
end)

-- Abandoned or turned in: the spot is in the list entry by now (the hook runs
-- before the server answers) or no longer needed.
ns.On("QUEST_REMOVED", function(_, questID) pickups()[questID] = nil end)

-- "Elwynn Forest 42, 65", or the quest log zone without a known spot.
function Abandoned.Place(entry)
    local map = entry.mapID and C_Map.GetMapInfo(entry.mapID)
    if map and entry.x then
        return ("%s %.0f, %.0f"):format(map.name, entry.x * 100, entry.y * 100)
    end
    return entry.zone or L.ZONE_OTHER
end
