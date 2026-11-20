local ADDON, ns = ...
local L = ns.L

--[[---------------------------------------------------------------------------
Broker.lua -- the selected quest's progress as a LibDataBroker data source
("ForeverQuestLog_Focus"), for Titan Panel, Forever Data Bar and the like:
the same quest as the selected quest tracker (Focus.Quest), its title and
the counts of its objectives. Only where another addon brought the library
(as the launcher, Options/MinimapButton.lua).
-----------------------------------------------------------------------------]]
local Broker = {}
ns.Broker = Broker

Broker.NAME = "ForeverQuestLog_Focus"
local GREEN, GREY, RED = "|cff40ff40", "|cff9d9d9d", "|cffff4040"

local function count(o)
    if o.percent then return ("%d%%"):format(o.percent) end
    if o.cur and o.max then return ("%d/%d"):format(o.cur, o.max) end
end

-- "Title  3/8 · 45%": done ones green; complete or failed in place of the counts.
function Broker.Text(q)
    if not q then return GREY .. L.BROKER_NONE .. "|r" end
    if q.isFailed then return ("%s  %s%s|r"):format(q.title, RED, L.FAILED) end
    if q.isComplete then return ("%s  %s%s|r"):format(q.title, GREEN, L.QUEST_COMPLETE) end
    local parts = {}
    for _, o in ipairs(q.objectives or {}) do
        local c = count(o)
        if c then parts[#parts + 1] = o.done and (GREEN .. c .. "|r") or c end
    end
    if #parts == 0 then return q.title end
    return q.title .. "  " .. table.concat(parts, " · ")
end

local function tooltip(tip)
    local q = ns.Focus.Quest()
    tip:AddLine(q and q.title or L.OPT_FOCUS)
    if not q then
        tip:AddLine(L.BROKER_NONE, 0.62, 0.62, 0.62)
        return
    end
    for _, o in ipairs(q.objectives or {}) do
        local g = o.done and 1 or 0.82
        tip:AddDoubleLine(o.text or "", count(o) or "", 1, g, g, o.done and 0.25 or 1, 1, o.done and 0.25 or 1)
    end
    if q.isComplete then tip:AddLine(L.QUEST_COMPLETE, 0.25, 1, 0.25) end
end

local obj, queued
function Broker.Update()
    queued = false
    if obj then obj.text = Broker.Text(ns.Focus.Quest()) end
end
local function queue()
    if obj and not queued then
        queued = true
        C_Timer.After(0, Broker.Update)
    end
end

function Broker.Register()
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    if obj or not ldb then return end
    obj = ldb:NewDataObject(Broker.NAME, {
        type = "data source", label = L.OPT_FOCUS, icon = ns.MinimapButton and ns.MinimapButton.ICON, text = "",
        OnClick = function(frame, button)
            local q = ns.Focus.Quest()
            if q then ns.Actions.QuestClick(frame, q, button) end
        end,
        OnTooltipShow = tooltip,
    })
    Broker.object = obj
    Broker.Update()
end
ns.On("PLAYER_LOGIN", Broker.Register)

-- As the selected quest tracker (Focus.lua), which also follows QUEST_WATCH_UPDATE first.
for _, event in ipairs({ "QUEST_WATCH_UPDATE", "SUPER_TRACKING_CHANGED", "QUEST_LOG_UPDATE",
    "QUEST_WATCH_LIST_CHANGED", "QUEST_TURNED_IN" }) do
    ns.On(event, queue)
end
ns.Settings.OnChange(function(key)
    if key == nil or key:find("^focus") then queue() end
end)
