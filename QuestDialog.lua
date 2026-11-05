local ADDON, ns = ...
local L, Settings, Position = ns.L, ns.Settings, ns.Position
local S = Settings.Get

-- The windows at an NPC: the greeting (GossipFrame) and the quest itself
-- (QuestFrame). Moved by the title bar, they open where they were left. They
-- replace each other while talking to an NPC and have the same size, so they
-- share one place: nothing jumps between them. Both are UI panels like the
-- world map, placed by Blizzard's panel manager, so the same way applies (see
-- WorldMap.lua): only C calls on them, a watcher puts them back while they are
-- open, and we step back for the session if another addon places one too.
local QuestDialog = { yielded = {} }   -- yielded[frame]: another addon places it
ns.QuestDialog = QuestDialog

local FRAMES = { "QuestFrame", "GossipFrame" }
local TITLE_H = 24
local SIDE = 64              -- leave the portrait (left) and the close button (right) free
local LEVEL_ABOVE_TITLE = 20 -- the NPC's name lies over the title bar
local WATCH_INTERVAL = 0.05

local built = false

function QuestDialog.ResetPosition()
    Settings.SetMany({ questDialogPlaced = false })
    -- Blizzard places them again the next time they open.
end

local function attach(frame)
    local handle = CreateFrame("Frame", nil, frame)
    local moving = false

    local function place()
        if QuestDialog.yielded[frame] or not S("questDialogMove") or not S("questDialogPlaced") then return end
        local point = S("questDialogPoint")
        local s = frame:GetScale()
        local x, y = S("questDialogX") / s, S("questDialogY") / s
        if Position.IsAt(frame, point, x, y) then return end
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, point, x, y)
        if not Position.IsAt(frame, point, x, y) then
            QuestDialog.yielded[frame] = true
            handle:EnableMouse(false)
            ns.Print(L.MSG_QUESTDIALOG_YIELDED)
        end
    end

    local function stopMoving()
        if not moving then return end
        frame:StopMovingOrSizing()
        moving = false
        local point, x, y = Position.NearestCorner(frame)
        Settings.SetMany({ questDialogPlaced = true, questDialogPoint = point, questDialogX = x, questDialogY = y })
    end

    local elapsed = 0
    local function watch(_, dt)
        elapsed = elapsed + dt
        if elapsed < WATCH_INTERVAL or moving then return end
        elapsed = 0
        place()
    end

    handle:SetFrameLevel(frame:GetFrameLevel() + LEVEL_ABOVE_TITLE)
    handle:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE, 0)
    handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SIDE, 0)
    handle:SetHeight(TITLE_H)
    handle:EnableMouse(true)
    handle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not S("questDialogMove") or QuestDialog.yielded[frame] then return end
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:StartMoving()
        moving = true
    end)
    handle:SetScript("OnMouseUp", stopMoving)
    -- Walking away from the NPC closes the window mid-drag: no OnMouseUp then.
    handle:SetScript("OnHide", stopMoving)
    handle:SetScript("OnEnter", function(self)
        if not S("questDialogMove") or QuestDialog.yielded[frame] then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.TIP_QUESTDIALOG_DRAG, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Runs only while the window is open (a child of it).
    handle:SetScript("OnUpdate", watch)
    frame:HookScript("OnShow", place)
end

function QuestDialog.Build()
    if built then return end
    built = true
    for _, name in ipairs(FRAMES) do
        if _G[name] then attach(_G[name]) end
    end
end

ns.On("PLAYER_LOGIN", function() QuestDialog.Build() end)
