-- A mock of the WoW API, just enough for Forever Quest Log. Lua 5.1, as in the game.
local M = { frames = {}, byName = {}, chat = {}, timers = {}, fontStrings = {}, popups = {}, registered = {},
            calls = {}, menus = {} }

local function record(name, ...) M.calls[#M.calls + 1] = { name, ... } end
M.record = record

local widget = {}
widget.__index = function(t, k)
    -- Only CamelCase keys are widget methods. Everything else is the addon's
    -- own data and must be nil as in the game.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(name, kind)
    local w = setmetatable({ _name = name, _kind = kind, _scripts = {}, _events = {},
                             _w = 0, _h = 0, _shown = true, _attr = {}, _alpha = 1, _scale = 1 }, widget)
    function w:GetName() return self._name end
    function w:GetObjectType() return self._kind end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end return fn(...) end
    end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    function w:SetTextColor(r, g, b) self._textColor = { r, g, b } end
    function w:SetChecked(v) self._checked = not not v end
    function w:GetChecked() return self._checked end
    function w:SetAttribute(k, v) self._attr[k] = v end
    function w:GetAttribute(k) return self._attr[k] end
    function w:SetSize(a, b) self._w, self._h = a, b end
    function w:SetWidth(v) self._w = v end
    function w:SetHeight(v) self._h = v end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:GetSize() return self._w, self._h end
    function w:Hide() self._shown = false end
    function w:Show() self._shown = true end
    function w:SetShown(v) if v then self:Show() else self:Hide() end end
    function w:IsShown() return self._shown end
    function w:IsVisible()
        local f = self
        while f do
            if not f._shown then return false end
            f = f._parent
        end
        return true
    end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha end
    function w:GetFrameLevel() return self._level or 3 end
    function w:SetParent(p) self._parent = p end
    function w:GetParent() return self._parent end
    function w:SetEnabled(on) self._enabled = on and true or false end
    function w:IsEnabled() return self._enabled ~= false end
    function w:SetFrameLevel(v) self._level = v end
    function w:SetScale(v) self._scale = v end
    function w:GetScale() return self._scale or 1 end
    function w:GetEffectiveScale() return self._scale or 1 end
    function w:SetMovable(v) self._movable = v end
    function w:IsMovable() return self._movable end
    function w:EnableMouse(v) self._mouse = v end
    function w:IsMouseOver() return self._mouseOver or false end
    function w:RegisterForDrag(...) self._drag = select("#", ...) > 0 end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:RegisterEvent(e)
        if M.validEvents and not M.validEvents[e] then error("unknown event " .. e) end
        self._events[e] = true
    end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:SetPoint(p, rel, p2, x, y)
        if type(rel) == "number" then x, y, rel, p2 = rel, p2, nil, nil end
        self._points = self._points or {}
        self._points[p] = { rel, p2, x, y }
        self._lastPoint = { p, rel, p2, x, y }
    end
    function w:ClearAllPoints() self._points = {} end
    function w:GetPoint() local a = self._lastPoint; if a then return a[1], a[2], a[3], a[4], a[5] end end
    -- Screen rectangle: tests set _rect = { left, bottom, width, height }.
    function w:GetLeft() return self._rect and self._rect[1] end
    function w:GetBottom() return self._rect and self._rect[2] end
    function w:GetRight() return self._rect and (self._rect[1] + self._rect[3]) end
    function w:GetTop() return self._rect and (self._rect[2] + self._rect[4]) end
    function w:SetColorTexture(r, g, b, a) self._texColor = { r, g, b, a } end
    function w:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
    function w:SetGradient(dir, a, b) self._gradient = { dir, a, b } end
    function w:SetTexture(t) self._texture = t end
    function w:GetTexture() return self._texture end
    function w:SetAtlas(a) self._atlas = a end
    function w:SetTexCoord(...) self._texCoord = { ... } end
    function w:AddMaskTexture(m) self._masks = (self._masks or 0) + 1 end
    function w:RemoveMaskTexture(m) self._masks = (self._masks or 1) - 1 end
    function w:CreateMaskTexture() return newWidget(nil, "MaskTexture") end
    function w:CreateTexture()
        local t = newWidget(nil, "Texture")
        t._parent = self
        return t
    end
    function w:StartMoving() self._moving = true end
    function w:StopMovingOrSizing() self._moving = false end
    function w:SetVerticalScroll(v) self._scroll = v end
    function w:GetVerticalScroll() return self._scroll or 0 end
    function w:GetVerticalScrollRange() return 0 end
    function w:SetScrollChild(c) self._child = c end
    function w:CreateFontString(_, _, template)
        local fs = newWidget(nil, "FontString")
        fs._parent = self
        fs._font = { "Fonts\\FRIZQT__.TTF", 12, "" }
        function fs:GetFont() return self._font[1], self._font[2], self._font[3] end
        function fs:SetFont(p, s, f) self._font = { p, s, f }; return true end
        function fs:SetFontObject() end
        function fs:GetStringWidth() return #(tostring(self._text or "")) * 6 end
        -- Wraps at the set width: one line per (width / 6) characters.
        function fs:GetStringHeight()
            local text = tostring(self._text or "")
            local perLine = (self._w and self._w > 0) and math.max(1, math.floor(self._w / 6)) or math.huge
            local n = math.max(1, math.ceil(#text / perLine))
            if self._maxLines and self._maxLines > 0 then n = math.min(n, self._maxLines) end
            return n * self._font[2]
        end
        function fs:SetMaxLines(n) self._maxLines = n end
        function fs:SetShadowOffset(x, y) self._shadow = { x, y } end
        M.fontStrings[#M.fontStrings + 1] = fs
        return fs
    end
    return w
end
M.newWidget = newWidget

function CreateFrame(kind, name, parent, template)
    if template == "POIButtonTemplate" and M.noPOI then error("no such template") end
    local f = newWidget(name, kind)
    f._parent, f._template = parent, template
    M.frames[#M.frames + 1] = f
    if name then M.byName[name] = f; _G[name] = f end
    if template == "POIButtonTemplate" then
        function f:SetQuestID(id) self.questID = id end
        function f:SetStyle(s) self.style = s end
        function f:SetSelected(v) self.selected = v end
        function f:UpdateButtonStyle() end
    end
    if template == "SecureActionButtonTemplate" then f._secure = true end
    if template == "CooldownFrameTemplate" then
        function f:SetCooldown(s, d) self._cooldown = { s, d } end
        function f:Clear() self._cooldown = nil end
    end
    return f
end

-- Delivers an event to every frame that registered it, in creation order.
function M.Fire(event, ...)
    for _, f in ipairs(M.frames) do
        local handler = f._events[event] and f:GetScript("OnEvent")
        if handler then handler(f, event, ...) end
    end
end

function M.RunTimers()
    for _ = 1, 5 do
        local list = M.timers
        M.timers = {}
        for _, fn in ipairs(list) do fn() end
        if #M.timers == 0 then return end
    end
end

UIParent = newWidget("UIParent")
UIParent._w, UIParent._h = 1920, 1080
UIParent._rect = { 0, 0, 1920, 1080 }
Minimap = newWidget("Minimap")
Minimap._w, Minimap._h = 260, 260
Minimap._rect = { 1652, 767, 260, 260 }
function Minimap:GetCenter() return 1782, 897 end
GameTooltip = newWidget("GameTooltip")
function GameTooltip:AddLine(t) self._lines = self._lines or {}; self._lines[#self._lines + 1] = t end
function GameTooltip:SetOwner() self._lines = {} end
function GameTooltip:IsOwned() return true end
function GameTooltip:SetQuestPartyProgress(id) record("SetQuestPartyProgress", id) end
function GameTooltip:SetQuestLogSpecialItem(i) record("SetQuestLogSpecialItem", i) end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) M.chat[#M.chat + 1] = m end }
SlashCmdList = {}
UISpecialFrames = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which, a) M.popups[#M.popups + 1] = { which = which, text = StaticPopupDialogs[which].text, arg = a } end
C_Timer = { After = function(_, fn) M.timers[#M.timers + 1] = fn end }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
InterfaceOptions_AddCategory = function(panel) M.registered[#M.registered + 1] = panel.name end
PixelUtil = { GetNearestPixelSize = function(v) return v end, GetPixelToUIUnitFactor = function() return 1 end }
Enum = { UITextureSliceMode = { Stretched = 1 }, SpellBookSpellBank = { Player = 0 } }
POIButtonUtil = { Style = { QuestInProgress = 1, QuestComplete = 2 } }
Constants = { QuestWatchConsts = { MAX_QUEST_WATCHES = 25 } }

M.locale = "enUS"
function GetLocale() return M.locale end
M.build = { "1.60.1", "70205", "Oct 2 2026", 16001 }
function GetBuildInfo() return M.build[1], M.build[2], M.build[3], M.build[4] end
M.state = { combat = false, money = 500, instance = nil, zone = "Stranglethorn Vale", ctrl = false, modified = {} }
function InCombatLockdown() return M.state.combat end
function IsControlKeyDown() return M.state.ctrl end
function IsModifiedClick(what) return M.state.modified[what] or false end
function IsInGroup() return M.state.group or false end
function GetMoney() return M.state.money end
function GetMoneyString(v) return v .. "c" end
function GetRealZoneText() return M.state.zone end
function GetCursorPosition() return M.state.cursorX or 0, M.state.cursorY or 0 end
function IsInInstance()
    if M.state.instance then return true, M.state.instance.kind end
    return false, "none"
end
function GetInstanceInfo() return M.state.instance and M.state.instance.name or "" end
function GetDifficultyColor(d) return ({ { r = 1, g = 0.1, b = 0.1 }, { r = 1, g = 0.5, b = 0.25 },
    { r = 1, g = 1, b = 0 }, { r = 0.25, g = 0.75, b = 0.25 }, { r = 0.5, g = 0.5, b = 0.5 } })[d] end
C_PlayerInfo = { GetContentDifficultyQuestForPlayer = function(id)
    local q = M.quest(id)
    if not q then return 3 end
    if q.level >= 38 then return 2 end
    if q.level >= 33 then return 3 end
    if q.level >= 28 then return 4 end
    return 5
end }

-- The quest log: headers and quests in order. A quest: id, title, level,
-- objectives { text, type, finished, have, need }, complete, failed,
-- autoComplete, item { link, texture, charges, whenComplete }, tag,
-- money, completionText.
M.log = {}
M.watches = {}
M.superTracked = 0

function M.quest(id)
    for _, e in ipairs(M.log) do if e.id == id then return e end end
end

local function logIndex(id)
    for i, e in ipairs(M.log) do if e.id == id then return i end end
end

C_QuestLog = {
    GetNumQuestLogEntries = function() return #M.log end,
    GetInfo = function(i)
        local e = M.log[i]
        if not e then return nil end
        if e.header then return { title = e.header, isHeader = true } end
        return { title = e.title, questID = e.id, level = e.level, isHeader = false, isTask = false,
                 isBounty = false, isAutoComplete = e.autoComplete or false, questLogIndex = i }
    end,
    GetLogIndexForQuestID = function(id) return logIndex(id) end,
    GetNumQuestWatches = function() return #M.watches end,
    GetQuestIDForQuestWatchIndex = function(i) return M.watches[i] end,
    GetQuestDifficultyLevel = function(id) return M.quest(id).level end,
    GetTitleForQuestID = function(id) local q = M.quest(id); return q and q.title end,
    IsComplete = function(id) return M.quest(id).complete or false end,
    IsFailed = function(id) return M.quest(id).failed or false end,
    GetQuestTagInfo = function(id) local q = M.quest(id); return q.tag and { tagName = q.tag } or nil end,
    GetQuestObjectives = function(id)
        local list = {}
        for _, o in ipairs(M.quest(id).objectives or {}) do
            list[#list + 1] = { text = o.text, type = o.type or "monster", finished = o.finished or false,
                numFulfilled = o.have or 0, numRequired = o.need or 1 }
        end
        return list
    end,
    GetRequiredMoney = function(id) return M.quest(id).money or 0 end,
    GetNextWaypointText = function(id) return M.quest(id).waypoint end,
    RemoveQuestWatch = function(id) record("RemoveQuestWatch", id) end,
    IsPushableQuest = function() return true end,
}
function GetNumQuestLeaderBoards(i) return #(M.log[i].objectives or {}) end
function GetQuestLogLeaderBoard(n, i)
    local o = M.log[i].objectives[n]
    return o.text, o.type or "monster", o.finished or false
end
function GetQuestProgressBarPercent(id) return M.quest(id).percent or 0 end
function GetQuestLogCompletionText(i) return M.log[i].completionText end
function GetQuestLogSpecialItemInfo(i)
    local it = M.log[i].item
    if not it then return nil end
    return it.link, it.texture, it.charges, it.whenComplete
end
function GetQuestLogSpecialItemCooldown() return 0, 0, 1 end
function IsQuestLogSpecialItemInRange() return 1 end
C_SuperTrack = {
    GetSuperTrackedQuestID = function() return M.superTracked end,
    SetSuperTrackedQuestID = function(id) M.superTracked = id; record("SetSuperTrackedQuestID", id) end,
}
QuestUtil = {
    CanRemoveQuestWatch = function() return true end,
    IsShowingQuestDetails = function() return false end,
    OpenQuestDetails = function(id) record("OpenQuestDetails", id) end,
    ShareQuest = function(id) record("ShareQuest", id) end,
}
function QuestMapFrame_OpenToQuestDetails(id) record("QuestMapFrame_OpenToQuestDetails", id) end
function ShowQuestComplete(id) record("ShowQuestComplete", id) end
function QuestMapQuestOptions_AbandonQuest(id) record("Abandon", id) end
ChatFrameUtil = {
    TryInsertQuestLinkForQuestID = function() return M.state.chatOpen or false end,
    InsertLink = function(link) record("InsertLink", link) end,
    GetActiveWindow = function() return M.state.chatOpen end,
}
-- The menu records its entries' texts and keeps their callbacks.
MenuUtil = { CreateContextMenu = function(owner, build)
    local menu = { entries = {} }
    local root = {
        CreateTitle = function(_, t) menu.entries[#menu.entries + 1] = { text = t } end,
        CreateButton = function(_, t, fn) menu.entries[#menu.entries + 1] = { text = t, fn = fn } end,
    }
    build(owner, root)
    M.menus[#M.menus + 1] = menu
    return menu
end }
SUPER_TRACK_QUEST = "Focus"
STOP_SUPER_TRACK_QUEST = "Stop focus"
OBJECTIVES_VIEW_IN_QUESTLOG = "Open quest details"
OBJECTIVES_SHOW_QUEST_MAP = "Show on map"
OBJECTIVES_STOP_TRACKING = "Untrack"
SHARE_QUEST = "Share"
ABANDON_QUEST_ABBREV = "Abandon"
QUEST_WATCH_QUEST_READY = "Ready for turn-in"
FAILED = "Failed"

-- Recipes
M.recipes = {}
C_TradeSkillUI = {
    GetRecipesTracked = function(isRecraft)
        local list = {}
        if not isRecraft then for _, r in ipairs(M.recipes) do list[#list + 1] = r.id end end
        return list
    end,
    SetRecipeTracked = function(id, on) record("SetRecipeTracked", id, on) end,
    OpenRecipe = function(id) record("OpenRecipe", id) end,
    IsRecipeProfessionLearned = function() return true end,
    GetRecipeLink = function(id) return "recipe:" .. id end,
}
local function recipe(id) for _, r in ipairs(M.recipes) do if r.id == id then return r end end end
ProfessionsUtil = {
    GetRecipeSchematic = function(id)
        local r = recipe(id)
        local slots = {}
        for _, g in ipairs(r.reagents) do
            slots[#slots + 1] = { required = true, reagents = { { itemID = g.itemID } }, quantityRequired = g.need,
                GetQuantityRequired = function(self) return self.quantityRequired end, have = g.have }
        end
        return { name = r.name, reagentSlotSchematics = slots }
    end,
    IsReagentSlotRequired = function(slot) return slot.required end,
    IsReagentSlotBasicRequired = function(slot) return slot.required end,
    AccumulateReagentsInPossession = function(reagents)
        for _, r in ipairs(M.recipes) do
            for _, g in ipairs(r.reagents) do if g.itemID == reagents[1].itemID then return g.have end end
        end
        return 0
    end,
}
C_Item = { GetItemNameByID = function(id) return M.itemNames and M.itemNames[id] end,
           RequestLoadItemDataByID = function(id) record("RequestLoadItemDataByID", id) end }

-- Blizzard's tracker, the frame the addon must leave alone except for
-- scale and alpha. Writing a field on it, calling a method other than
-- those, Hide, SetParent or SetPoint, is recorded as a violation.
M.violations = {}
local otf = newWidget("ObjectiveTrackerFrame", "Frame")
otf.isCollapsed = false
local allowed = { SetScale = true, SetAlpha = true, GetScale = true, GetAlpha = true }
ObjectiveTrackerFrame = setmetatable({}, {
    __index = function(_, k)
        local v = otf[k]
        if type(v) == "function" and not allowed[k] then
            return function(_, ...)
                M.violations[#M.violations + 1] = "call " .. k
                return v(otf, ...)
            end
        elseif type(v) == "function" then
            return function(_, ...) return v(otf, ...) end
        end
        return v
    end,
    __newindex = function(_, k, v)
        M.violations[#M.violations + 1] = "write " .. tostring(k)
        otf[k] = v
    end,
})
M.objectiveTracker = otf

-- Secure variables: everything Blizzard's is secure in the mock.
function issecurevariable() return true end

return M
