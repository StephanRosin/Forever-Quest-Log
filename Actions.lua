local ADDON, ns = ...
local L = ns.L

-- What clicks on a quest or recipe do: the same calls Blizzard's tracker
-- makes (QuestObjectiveTrackerMixin:OnBlockHeaderClick and
-- ProfessionsRecipeTrackerMixin:OnBlockHeaderClick, build 1.60.1.70205).
-- None of them is protected; they run in our own (insecure) code, which only
-- calls Blizzard's functions and never writes into Blizzard's tables.
local Actions = {}
ns.Actions = Actions

local function canUntrack()
    return not (QuestUtil and QuestUtil.CanRemoveQuestWatch) or QuestUtil.CanRemoveQuestWatch()
end

local function openDetails(questID)
    if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(questID) end
end

-- The right-click menu, Blizzard's entries in Blizzard's order.
local function questMenu(owner, questID)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(C_QuestLog.GetTitleForQuestID(questID) or "")
        if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then
            root:CreateButton(SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(questID) end)
        else
            root:CreateButton(STOP_SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(0) end)
        end
        local showing = QuestUtil and QuestUtil.IsShowingQuestDetails and QuestUtil.IsShowingQuestDetails(questID)
        root:CreateButton(showing and OBJECTIVES_HIDE_VIEW_IN_QUESTLOG or OBJECTIVES_VIEW_IN_QUESTLOG, function()
            QuestUtil.OpenQuestDetails(questID)
        end)
        root:CreateButton(OBJECTIVES_SHOW_QUEST_MAP, function() openDetails(questID) end)
        if canUntrack() then
            root:CreateButton(OBJECTIVES_STOP_TRACKING, function() C_QuestLog.RemoveQuestWatch(questID) end)
        end
        if C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
            root:CreateButton(SHARE_QUEST, function() QuestUtil.ShareQuest(questID) end)
        end
        root:CreateButton(ABANDON_QUEST_ABBREV, function() QuestMapQuestOptions_AbandonQuest(questID) end)
    end)
end

function Actions.QuestClick(owner, quest, mouseButton)
    local questID = quest.id
    if ChatFrameUtil and ChatFrameUtil.TryInsertQuestLinkForQuestID
        and ChatFrameUtil.TryInsertQuestLinkForQuestID(questID) then
        return
    end
    if mouseButton == "RightButton" then
        questMenu(owner, questID)
        return
    end
    if IsModifiedClick("QUESTWATCHTOGGLE") then
        if canUntrack() then C_QuestLog.RemoveQuestWatch(questID) end
    elseif quest.isAutoComplete and quest.isComplete and ShowQuestComplete then
        ShowQuestComplete(questID)
    else
        openDetails(questID)
    end
end

local function anchorTooltip(owner)
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, 0)
    GameTooltip:SetOwner(owner, "ANCHOR_PRESERVE")
end

local function partyMembersOnQuest(questID)
    return QuestUtils_GetNumPartyMembersOnQuest and QuestUtils_GetNumPartyMembersOnQuest(questID) or 0
end

-- On hover: the title and the quest's short text, then the party's progress
-- the way Blizzard's quest log tooltip adds it (QuestMapLogTitleButton_OnEnter).
-- Without the tooltip option only the party progress, as Blizzard's tracker.
function Actions.QuestEnter(owner, quest)
    if not ns.Settings.Get("questTooltip") then
        if not IsInGroup() then return end
        anchorTooltip(owner)
        GameTooltip:SetQuestPartyProgress(quest.id)
        return
    end
    anchorTooltip(owner)
    GameTooltip:SetText(quest.title, 1, 0.82, 0, 1, true)
    if quest.overview then GameTooltip:AddLine(quest.overview, 1, 1, 1, true) end
    if partyMembersOnQuest(quest.id) > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(PARTY_QUEST_STATUS_ON or L.PARTY_ON_QUEST)
        local omitTitle, ignoreActivePlayer = true, true
        GameTooltip:SetQuestPartyProgress(quest.id, omitTitle, ignoreActivePlayer)
    end
    GameTooltip:Show()
end

function Actions.Leave()
    GameTooltip:Hide()
end

-- Recipes ---------------------------------------------------------------------

local function openRecipe(recipe)
    if recipe.isRecraft then return end
    if not ProfessionsFrame and ProfessionsFrame_LoadUI then ProfessionsFrame_LoadUI() end
    if C_TradeSkillUI.IsRecipeProfessionLearned and C_TradeSkillUI.IsRecipeProfessionLearned(recipe.id) then
        C_TradeSkillUI.OpenRecipe(recipe.id)
    elseif Professions and Professions.InspectRecipe then
        Professions.InspectRecipe(recipe.id)
    end
end

function Actions.RecipeClick(owner, recipe, mouseButton)
    if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.GetActiveWindow
        and ChatFrameUtil.GetActiveWindow() then
        local link = C_TradeSkillUI.GetRecipeLink(recipe.id)
        if link then ChatFrameUtil.InsertLink(link) end
        return
    end
    if mouseButton ~= "RightButton" then
        if IsModifiedClick("RECIPEWATCHTOGGLE") then
            C_TradeSkillUI.SetRecipeTracked(recipe.id, false, recipe.isRecraft)
        else
            openRecipe(recipe)
        end
        return
    end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local inBook = C_SpellBook and C_SpellBook.IsSpellInSpellBook
            and C_SpellBook.IsSpellInSpellBook(recipe.id, Enum.SpellBookSpellBank.Player, false)
        if not recipe.isRecraft and inBook then
            root:CreateButton(PROFESSIONS_TRACKING_VIEW_RECIPE, function() C_TradeSkillUI.OpenRecipe(recipe.id) end)
        end
        root:CreateButton(PROFESSIONS_UNTRACK_RECIPE, function()
            C_TradeSkillUI.SetRecipeTracked(recipe.id, false, recipe.isRecraft)
        end)
    end)
end
