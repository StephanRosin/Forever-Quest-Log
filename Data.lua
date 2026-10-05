local ADDON, ns = ...
local L = ns.L

-- What the tracker shows, read from the game: the watched quests and the
-- tracked recipes as plain tables. Nothing here draws; Tracker.lua does.
-- The functions are the ones Blizzard's own tracker uses
-- (Blizzard_QuestObjectiveTracker.lua, Blizzard_ProfessionsRecipeTracker.lua
-- in build 1.60.1.70205).
local Data = {}
ns.Data = Data

-- Quest log headers ---------------------------------------------------------

-- questID -> the title of the quest log header it sits under (the zone, or
-- "Dungeons", a class name, ...). Built from the whole log at once.
function Data.QuestHeaders()
    local headers = {}
    local current
    local n = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                current = info.title
            elseif info.questID then
                headers[info.questID] = current
            end
        end
    end
    return headers
end

-- Objectives ----------------------------------------------------------------

-- "Young Tiger slain: 7/10" or "7/10 Young Tiger slain" -> text, 7, 10.
-- Anything else comes back as it is, without numbers.
function Data.SplitCount(text)
    if type(text) ~= "string" then return "", nil, nil end
    local name, cur, max = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
    if name and name ~= "" then return name, tonumber(cur), tonumber(max) end
    cur, max, name = text:match("^%s*(%d+)%s*/%s*(%d+)%s+(.+)$")
    if name then return name, tonumber(cur), tonumber(max) end
    return text, nil, nil
end

-- The quest's objectives: text without the count, cur / max (counted
-- objectives only), done, and percent for a progress-bar objective.
local function objectives(questID, logIndex)
    local list = {}
    local infos = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}
    local n = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(logIndex) or #infos
    for i = 1, n do
        -- Blizzard's tracker reads the leader board text (suppressing the
        -- percentage in it); the objective info has the counts.
        local text, kind, finished = GetQuestLogLeaderBoard(i, logIndex, true)
        local info = infos[i]
        if text then
            local name, cur, max = Data.SplitCount(text)
            if info and info.numRequired and info.numRequired > 1 then
                cur, max = info.numFulfilled, info.numRequired
            end
            local o = { text = name, cur = cur, max = max, done = finished and true or false, kind = kind }
            if kind == "progressbar" and GetQuestProgressBarPercent then
                o.percent = GetQuestProgressBarPercent(questID)
                o.text = text
                o.cur, o.max = nil, nil
            end
            list[#list + 1] = o
        end
    end
    return list
end

-- Level colour: the content difficulty, as Blizzard colours quest titles.
local function levelColor(questID, level)
    if C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer and GetDifficultyColor then
        local c = GetDifficultyColor(C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID))
        if c then return { c.r, c.g, c.b } end
    end
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level)
        if c then return { c.r, c.g, c.b } end
    end
    return { 1, 0.82, 0 }
end

local function tagName(questID)
    local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questID)
    if tag and tag.tagName and tag.tagName ~= "" then return tag.tagName end
    return nil
end

local function specialItem(logIndex, isComplete)
    if not GetQuestLogSpecialItemInfo then return nil end
    local link, texture, charges, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
    if not texture or (isComplete and not showWhenComplete) then return nil end
    return { link = link, texture = texture, charges = charges, logIndex = logIndex }
end

-- One quest as the tracker draws it, or nil when it is no longer in the
-- log. watchIndex: its place in Blizzard's watch order.
function Data.Quest(questID, watchIndex, headers, superTracked)
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex then return nil end
    local info = C_QuestLog.GetInfo(logIndex)
    if not info or info.isHeader then return nil end
    -- What Blizzard's tracker leaves out (ShouldDisplayQuest).
    if info.isTask or info.isBounty then return nil end

    local level = (C_QuestLog.GetQuestDifficultyLevel and C_QuestLog.GetQuestDifficultyLevel(questID)) or info.level or 0
    local isComplete = C_QuestLog.IsComplete(questID) and true or false
    local q = {
        id = questID,
        title = info.title or C_QuestLog.GetTitleForQuestID(questID) or "",
        level = level,
        levelColor = levelColor(questID, level),
        zone = headers and headers[questID] or nil,
        tag = tagName(questID),
        watchIndex = watchIndex or 0,
        logIndex = logIndex,
        isComplete = isComplete,
        isFailed = C_QuestLog.IsFailed and C_QuestLog.IsFailed(questID) or false,
        isAutoComplete = info.isAutoComplete and true or false,
        superTracked = superTracked == questID,
        objectives = objectives(questID, logIndex),
        item = specialItem(logIndex, isComplete),
    }
    if isComplete and not q.isAutoComplete and GetQuestLogCompletionText then
        local text = GetQuestLogCompletionText(logIndex)
        if text and text ~= "" then q.completionText = text end
    end
    -- The way-point line, for the quest the map arrow points to (or, when
    -- complete, instead of "Ready for turn-in" when there is no completion
    -- text), as Blizzard's tracker.
    if C_QuestLog.GetNextWaypointText and (q.superTracked or (isComplete and not q.completionText)) then
        q.waypoint = C_QuestLog.GetNextWaypointText(questID)
    end
    local money = C_QuestLog.GetRequiredMoney and C_QuestLog.GetRequiredMoney(questID) or 0
    if money and money > 0 and not isComplete then
        local have = GetMoney and GetMoney() or 0
        if have < money then q.money = { have = have, need = money } end
    end
    return q
end

-- The watched quests in Blizzard's watch order.
function Data.Quests()
    local list = {}
    local headers = Data.QuestHeaders()
    local superTracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() or 0
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        local q = questID and Data.Quest(questID, i, headers, superTracked)
        if q then list[#list + 1] = q end
    end
    return list
end

-- Quests in the log and how many it holds, as Forever's quest log counts
-- them (Camelot/QuestMapFrameUtils.lua).
function Data.LogCount()
    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    local max = Constants and Constants.QuestLogConsts and Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT
    if not max and C_QuestLog.GetMaxNumQuestsCanAccept then max = C_QuestLog.GetMaxNumQuestsCanAccept() end
    return numQuests or 0, max or 0
end

function Data.MaxWatches()
    return (Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES) or 25
end

-- Recipes -------------------------------------------------------------------

-- An item's name, asking the client to load it when it is not cached yet
-- (GET_ITEM_INFO_RECEIVED then redraws).
local function itemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return name
end

-- One tracked recipe: its name and the required reagents with how many the
-- player has, as Blizzard's ProfessionsRecipeTracker builds them.
function Data.Recipe(recipeID, isRecraft)
    if not (ProfessionsUtil and ProfessionsUtil.GetRecipeSchematic) then return nil end
    local schematic = ProfessionsUtil.GetRecipeSchematic(recipeID, isRecraft)
    if not schematic then return nil end
    local name = schematic.name or ""
    if isRecraft and PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER then
        name = PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER:format(name)
    end
    local r = { id = recipeID, isRecraft = isRecraft and true or false, name = name, reagents = {} }
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if ProfessionsUtil.IsReagentSlotRequired(slot) then
            local reagent = slot.reagents and slot.reagents[1]
            local text
            if reagent and ProfessionsUtil.IsReagentSlotBasicRequired(slot) then
                if reagent.itemID then
                    text = itemName(reagent.itemID)
                elseif reagent.currencyID and C_CurrencyInfo then
                    local c = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
                    text = c and c.name
                end
            elseif slot.slotInfo then
                text = slot.slotInfo.slotText
            end
            if reagent then
                local need = slot.GetQuantityRequired and slot:GetQuantityRequired(reagent) or slot.quantityRequired or 1
                local have = ProfessionsUtil.AccumulateReagentsInPossession(slot.reagents) or 0
                r.reagents[#r.reagents + 1] = {
                    text = text or L.LOADING, cur = math.min(have, need), max = need, done = have >= need,
                }
            end
        end
    end
    return r
end

function Data.Recipes()
    local list = {}
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked) then return list end
    for _, isRecraft in ipairs({ false, true }) do
        for _, recipeID in ipairs(C_TradeSkillUI.GetRecipesTracked(isRecraft) or {}) do
            local r = Data.Recipe(recipeID, isRecraft)
            if r then list[#list + 1] = r end
        end
    end
    return list
end
