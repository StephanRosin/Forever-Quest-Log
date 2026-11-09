local ADDON, ns = ...
local L, Settings, Media, Rows = ns.L, ns.Settings, ns.Media, ns.Rows
local S = Settings.Get

-- Task lists undocked from the tracker: each a window of its own, like a
-- sticky note, moved by its title, sized at its corner, scrolled with the
-- wheel. Closing it docks the list back into the tracker. Where it is and
-- how big is kept on the list (list.note), per character with the lists.
local Notes = {}
ns.Notes = Notes

local TITLE_H, PAD, BUTTON, GRIP = 24, 8, 14, 16
local MIN_W, MIN_H, MAX_W, MAX_H = 160, 80, 700, 900
local ACCENT = { 0.31, 0.76, 0.97 }

local windows = {}          -- list -> its window

-- The window's place in UIParent units, from its top left corner.
local function save(win)
    local note = win.list.note
    note.x = math.floor(win:GetLeft() + 0.5)
    note.y = math.floor(win:GetTop() - UIParent:GetHeight() + 0.5)
    note.w = math.floor(win:GetWidth() + 0.5)
    note.h = math.floor(win:GetHeight() + 0.5)
end

local function place(win)
    local note = win.list.note
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", note.x, note.y)
    win:SetSize(note.w, note.h)
end

local function applyLook(win)
    Media.ApplyBackground(win.bg, S("bgMode"), S("bgColor"), S("bgAlpha") / 100, S("bgTexture"))
    local radius = ns.Corners.Clamp(S("cornerRadius"), win:GetWidth(), win:GetHeight())
    ns.Corners.Fit(win.clip, win, radius, { win.bg })
    ns.Border.Draw(win, win, {
        style = S("borderStyle"), size = S("borderSize"), color = S("borderColor"), radius = radius,
        shadow = S("shadowEnabled"), shadowSize = S("shadowSize"), shadowAlpha = S("shadowAlpha") / 100,
    })
end

local function titleButton(win, texture, tooltip, onClick)
    local b = CreateFrame("Button", nil, win.title)
    b:SetSize(BUTTON, BUTTON)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(texture)
    b.icon:SetAlpha(0.7)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(0.7)
        GameTooltip:Hide()
    end)
    return b
end

local function scrollBy(win, delta)
    local most = math.max(0, win.child:GetHeight() - win.scroll:GetHeight())
    win.scroll:SetVerticalScroll(math.max(0, math.min(most, win.scroll:GetVerticalScroll() - delta * 30)))
end

local function create(list)
    local win = CreateFrame("Frame", nil, UIParent)
    win.list = list
    win:SetFrameStrata("MEDIUM")
    win:SetMovable(true)
    win:SetResizable(true)
    if win.SetResizeBounds then win:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H) end
    win:SetClampedToScreen(true)
    if win.SetDontSavePosition then win:SetDontSavePosition(true) end
    win:EnableMouse(true)
    win.bg = win:CreateTexture(nil, "BACKGROUND")
    win.bg:SetAllPoints()
    win.clip = {}

    -- The title: drag to move; + adds, the gear is the list's menu, x docks.
    win.title = CreateFrame("Frame", nil, win)
    win.title:SetPoint("TOPLEFT", PAD, 0)
    win.title:SetPoint("TOPRIGHT", -PAD, 0)
    win.title:SetHeight(TITLE_H)
    win.title:EnableMouse(true)
    win.title:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then win:StartMoving() end
    end)
    win.title:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        save(win)
        place(win)
    end)
    win.close = titleButton(win, "Interface\\Buttons\\UI-StopButton", L.TASK_DOCK, function() ns.Tasks.Dock(win.list) end)
    win.close:SetPoint("RIGHT", 0, 0)
    win.gear = titleButton(win, Media.Icon("Gear"), L.TIP_TASK_MENU, function(self) ns.TaskUI.ListMenu(self, win.list) end)
    win.gear:SetPoint("RIGHT", win.close, "LEFT", -4, 0)
    win.add = titleButton(win, Media.Icon("Plus"), L.TIP_TASK_ADD, function() ns.TaskUI.OpenAdd(win.list) end)
    win.add:SetPoint("RIGHT", win.gear, "LEFT", -4, 0)
    win.name = win.title:CreateFontString(nil, "OVERLAY")
    win.name:SetPoint("LEFT", 0, 0)
    win.name:SetPoint("RIGHT", win.add, "LEFT", -6, 0)
    win.name:SetJustifyH("LEFT")
    win.name:SetWordWrap(false)

    -- The entries, scrolled with the wheel when the note is too small.
    win.scroll = CreateFrame("ScrollFrame", nil, win)
    win.scroll:SetPoint("TOPLEFT", PAD, -TITLE_H)
    win.scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    win.child = CreateFrame("Frame", nil, win.scroll)
    win.child:SetSize(1, 1)
    win.scroll:SetScrollChild(win.child)
    win.scroll:EnableMouseWheel(true)
    win.scroll:SetScript("OnMouseWheel", function(_, delta) scrollBy(win, delta) end)
    win.rows = {}

    -- The corner: drag to size.
    win.grip = CreateFrame("Button", nil, win)
    win.grip:SetSize(GRIP, GRIP)
    win.grip:SetPoint("BOTTOMRIGHT", 0, 0)
    win.grip:SetFrameLevel(win:GetFrameLevel() + 20)
    win.grip.icon = win.grip:CreateTexture(nil, "OVERLAY")
    win.grip.icon:SetAllPoints()
    win.grip.icon:SetTexture(Media.Icon("Resize"))
    win.grip.icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
    win.grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    win.grip:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        save(win)
        place(win)
        Notes.Layout()
    end)
    win:SetScript("OnSizeChanged", function() if win.shownOnce then Notes.LayoutWindow(win) end end)
    return win
end

function Notes.LayoutWindow(win)
    local list = win.list
    local style = Settings.TextStyle("zone")
    Media.ApplyText(win.name, style)
    local done = 0
    for _, entry in ipairs(list.entries) do
        if ns.Tasks.Line(entry).done then done = done + 1 end
    end
    win.name:SetText(list.name .. "  " .. done .. "/" .. #list.entries)
    local width = math.max(1, win:GetWidth() - 2 * PAD)
    win.child:SetWidth(width)
    local y = 0
    for i, entry in ipairs(list.entries) do
        local row = win.rows[i]
        if not row then
            row = Rows.NewTaskRow(win.child)
            win.rows[i] = row
        end
        if i > 1 then y = y + S("questSpacing") end
        local h = Rows.LayoutTask(row, { list = list, task = entry, line = ns.Tasks.Line(entry) }, width)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", win.child, "TOPLEFT", 0, -y)
        row:Show()
        y = y + h
    end
    for i = #list.entries + 1, #win.rows do win.rows[i]:Hide() end
    win.child:SetHeight(math.max(1, y))
    scrollBy(win, 0)
    applyLook(win)
end

-- Every undocked list gets its window, the others lose theirs.
function Notes.Layout()
    local undocked = {}
    for _, list in ipairs(ns.Tasks.Lists()) do
        if list.undocked then
            undocked[list] = true
            local win = windows[list] or create(list)
            windows[list] = win
            if not win:IsShown() or not win.shownOnce then place(win) end
            win:Show()
            win.shownOnce = true
            Notes.LayoutWindow(win)
        end
    end
    -- Hidden, not dropped: frames cannot be freed, docking again reuses it.
    for list, win in pairs(windows) do
        if not undocked[list] then win:Hide() end
    end
end

Notes.windows = windows
