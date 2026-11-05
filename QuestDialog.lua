local ADDON, ns = ...
local L, Settings, Position = ns.L, ns.Settings, ns.Position
local S = Settings.Get

-- The window an NPC offers or takes a quest in (QuestFrame): moved by its
-- title bar, opening where it was left. It is a UI panel like the world map,
-- placed by Blizzard's panel manager, so the same way applies (see
-- WorldMap.lua): only C calls on it, a watcher puts it back while it is open,
-- and we step back for the session if another addon places it too.
local QuestDialog = { yielded = false }
ns.QuestDialog = QuestDialog

local TITLE_H = 24
local SIDE = 64              -- leave the portrait (left) and the close button (right) free
local LEVEL_ABOVE_TITLE = 20 -- the NPC's name lies over the title bar
local WATCH_INTERVAL = 0.05

local dialog, handle

local function yieldToOtherAddon()
    QuestDialog.yielded = true
    handle:EnableMouse(false)
    ns.Print(L.MSG_QUESTDIALOG_YIELDED)
end

function QuestDialog.Place()
    if not dialog or QuestDialog.yielded or not S("questDialogMove") or not S("questDialogPlaced") then return end
    local point = S("questDialogPoint")
    local s = dialog:GetScale()
    local x, y = S("questDialogX") / s, S("questDialogY") / s
    if Position.IsAt(dialog, point, x, y) then return end
    dialog:ClearAllPoints()
    dialog:SetPoint(point, UIParent, point, x, y)
    if not Position.IsAt(dialog, point, x, y) then yieldToOtherAddon() end
end

function QuestDialog.ResetPosition()
    Settings.SetMany({ questDialogPlaced = false })
    -- Blizzard places it again the next time it opens.
end

local function stopMoving()
    if not QuestDialog.moving then return end
    dialog:StopMovingOrSizing()
    QuestDialog.moving = nil
    local point, x, y = Position.NearestCorner(dialog)
    Settings.SetMany({ questDialogPlaced = true, questDialogPoint = point, questDialogX = x, questDialogY = y })
end

local elapsed = 0
local function watch(_, dt)
    elapsed = elapsed + dt
    if elapsed < WATCH_INTERVAL or QuestDialog.moving then return end
    elapsed = 0
    QuestDialog.Place()
end

function QuestDialog.Build()
    if dialog or not _G.QuestFrame then return end
    dialog = _G.QuestFrame
    handle = CreateFrame("Frame", nil, dialog)
    handle:SetFrameLevel(dialog:GetFrameLevel() + LEVEL_ABOVE_TITLE)
    handle:SetPoint("TOPLEFT", dialog, "TOPLEFT", SIDE, 0)
    handle:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -SIDE, 0)
    handle:SetHeight(TITLE_H)
    handle:EnableMouse(true)
    handle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not S("questDialogMove") or QuestDialog.yielded then return end
        dialog:SetMovable(true)
        dialog:SetClampedToScreen(true)
        dialog:StartMoving()
        QuestDialog.moving = true
    end)
    handle:SetScript("OnMouseUp", stopMoving)
    -- Walking away from the NPC closes the window mid-drag: no OnMouseUp then.
    handle:SetScript("OnHide", stopMoving)
    handle:SetScript("OnEnter", function(self)
        if not S("questDialogMove") or QuestDialog.yielded then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.TIP_QUESTDIALOG_DRAG, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Runs only while the window is open (a child of it).
    handle:SetScript("OnUpdate", watch)
    dialog:HookScript("OnShow", QuestDialog.Place)
end

ns.On("PLAYER_LOGIN", function() QuestDialog.Build() end)
