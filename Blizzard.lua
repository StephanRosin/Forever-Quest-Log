local ADDON, ns = ...

-- Blizzard's objective tracker, made invisible without touching its code.
--
-- Its quest item buttons call UseQuestLogSpecialItem with an index its
-- layout code writes; if that code ever ran tainted, using a quest item
-- could be blocked. The right managed frame container it sits in also lays
-- out the boss and arena frames (protected). So nothing here writes a field
-- on it, calls one of its Lua methods, hides it or re-parents it (Hide and
-- SetParent would run its OnHide, and with it the container's Layout, in
-- our context). Only two C calls: a tiny scale (nothing left to click; the
-- container lays it out as almost zero high next time it lays out, itself)
-- and alpha 0.
local Blizzard = {}
ns.Blizzard = Blizzard

Blizzard.SCALE = 0.001

local function tracker() return _G.ObjectiveTrackerFrame end

-- Hidden as wanted, or nothing to hide.
function Blizzard.IsHidden()
    local f = tracker()
    if not f then return true end
    return f:GetScale() <= Blizzard.SCALE * 1.5 and f:GetAlpha() == 0
end

function Blizzard.Hide()
    local f = tracker()
    if not f or ns.Settings.Get("useBlizzard") then return end
    if f:GetScale() > Blizzard.SCALE * 1.5 then f:SetScale(Blizzard.SCALE) end
    if f:GetAlpha() ~= 0 then f:SetAlpha(0) end
end

-- Called from the tracker's update: Edit Mode or a layout change may set
-- the scale back.
function Blizzard.Check()
    if not Blizzard.IsHidden() then Blizzard.Hide() end
end

ns.On("PLAYER_ENTERING_WORLD", function() Blizzard.Hide() end)
ns.On("EDIT_MODE_LAYOUTS_UPDATED", function() Blizzard.Hide() end)

-- Fields of Blizzard's that addon code must never have written. A tainted
-- one shows in /fql status (issecurevariable is false for it).
Blizzard.WATCHED = {
    { "ObjectiveTrackerFrame", "isCollapsed" },
    { "ObjectiveTrackerFrame", "dirty" },
    { "QuestObjectiveTracker", "isDirty" },
    { "QuestObjectiveTracker", "usedBlocks" },
    { "RightManagedFrameContainer", "showingFrames" },
}

function Blizzard.TaintReport()
    local lines = {}
    if not issecurevariable then return lines end
    for _, w in ipairs(Blizzard.WATCHED) do
        local t = _G[w[1]]
        if t then
            local secure, by = issecurevariable(t, w[2])
            lines[#lines + 1] = { name = w[1] .. "." .. w[2], secure = secure, by = by }
        end
    end
    return lines
end
