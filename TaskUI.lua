local ADDON, ns = ...
local L, Style, Tasks = ns.L, ns.Style, ns.Tasks

-- Managing the task lists: one small window for typing (a new list's name, an
-- entry, a new amount) and the right-click menus. The same field takes items
-- and text: pick a suggestion for an item, Enter on anything else is text.
local TaskUI = {}
ns.TaskUI = TaskUI

local WIDTH, PAD = 320, 10
local FIELD_H, AMOUNT_W = 22, 56
local STEPPER_W, MAX_AMOUNT = 14, 9999
local OK_W, OK_H, OK_GAP = 70, 24, 8
local ROW_H, ICON = 20, 16
local FONT = "Friz Quadrata"

local popup

local function newField(parent, width)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width, FIELD_H)
    e:SetAutoFocus(false)
    e:SetFont(ns.Media.FontPath(FONT), 12, "")
    Style.Paint(e, "text")
    e:SetTextInsets(6, 6, 0, 0)
    Style.Fill(e, "control")
    Style.Border(e)
    return e
end

-- Up and down by one, from the arrow keys or the field's arrow buttons.
local function stepAmount(field, step)
    local amount = (tonumber(field:GetText()) or 1) + step
    field:SetText(tostring(math.max(1, math.min(MAX_AMOUNT, amount))))
    Style.SetBorderColor(field, "border")
end

local function newStepButton(field, icon, step)
    local b = CreateFrame("Button", nil, field)
    b:SetSize(STEPPER_W, FIELD_H / 2 - 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(ns.Media.Icon(icon))
    local function paint(colorKey)
        local c = Style.COLORS[colorKey]
        b.icon:SetVertexColor(c[1], c[2], c[3])
    end
    paint("muted")
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() stepAmount(field, step) end)
    return b
end

local function addStepper(field)
    field.stepUp = newStepButton(field, "ChevronUp", 1)
    field.stepUp:SetPoint("TOPRIGHT", -1, -1)
    field.stepDown = newStepButton(field, "ChevronDown", -1)
    field.stepDown:SetPoint("BOTTOMRIGHT", -1, 1)
end

local function close()
    popup.edit:ClearFocus()
    popup.amount:ClearFocus()
    popup:Hide()
    GameTooltip:Hide()
end

-- Suggestions ---------------------------------------------------------------

local function paintSuggestions()
    for i, row in ipairs(popup.rows) do
        row.selected:SetShown(i == popup.selection)
    end
end

local function showSuggestions(results)
    popup.results, popup.selection = results, nil
    local list = popup.list
    for i = #popup.rows + 1, #results do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(WIDTH - 2, ROW_H)
        row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_H)
        row.selected = row:CreateTexture(nil, "BACKGROUND")
        row.selected:SetAllPoints()
        local c = Style.COLORS.accent
        row.selected:SetColorTexture(c[1], c[2], c[3], 0.25)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetPoint("CENTER", row, "LEFT", 4 + ICON / 2, 0)
        row.text = Style.Text(row, 12)
        row.text:SetPoint("LEFT", 4 + ICON + 6, 0)
        row.text:SetPoint("RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self) TaskUI.AddSuggestion(self.item) end)
        row:SetScript("OnEnter", function(self)
            popup.selection = self.index
            paintSuggestions()
            if self.item.zone then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.item.id)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.index = i
        popup.rows[i] = row
    end
    for i, row in ipairs(popup.rows) do
        local item = results[i]
        row:SetShown(item ~= nil)
        if item then
            row.item = item
            row.text:SetText(item.name)
            local place = Tasks.PLACE_TEXTURE[item.kind or ""]
            if place then
                row.icon:SetTexture(place[1])
                row.icon:SetTexCoord(place[2], place[3], place[4], place[5])
                row.text:SetTextColor(1, 1, 1)
            elseif item.zone then -- a client without atlas info
                row.icon:SetAtlas(item.kind == "raid" and "Raid" or "Dungeon")
                row.text:SetTextColor(1, 1, 1)
            else
                row.icon:SetTexture(C_Item.GetItemIconByID(item.id))
                -- cut the frame like the zone icon; also clears the coords of a reused place row
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                local r, g, b = C_Item.GetItemQualityColor(item.quality)
                row.text:SetTextColor(r, g, b)
            end
        end
    end
    list:SetHeight(#results * ROW_H + 2)
    list:SetShown(#results > 0)
    paintSuggestions()
end

local function clearEntry()
    popup.place = nil
    popup.edit:SetText("")
    popup.amount:SetText("1")
    showSuggestions({})
    popup.edit:SetFocus()
end

-- An item goes on the list; a zone only goes into the text, which the
-- player finishes and adds with Enter.
function TaskUI.AddSuggestion(item)
    if item.zone then
        local text = popup.edit:GetText():match("^%s*(.-)%s*$"):sub(1, item.from - 1) .. item.name
        popup.edit:SetText(text)
        popup.edit:SetCursorPosition(#text)
        popup.place = item
        showSuggestions({})
        popup.edit:SetFocus()
        return
    end
    Tasks.AddItem(popup.addTo, item, popup.amount:GetText())
    clearEntry()
end

local function moveSelection(step)
    local n = #popup.results
    if n == 0 then return end
    popup.selection = ((popup.selection or (step > 0 and 0 or 1)) - 1 + step) % n + 1
    paintSuggestions()
end

-- The window ----------------------------------------------------------------

local function submit()
    local text = popup.edit:GetText()
    local picked = popup.results[popup.selection or 0]
    if picked and picked.zone then
        TaskUI.AddSuggestion(picked)
    elseif popup.addTo then
        local item = popup.results[popup.selection or 0] or Tasks.FindExact(text)
        if item then
            TaskUI.AddSuggestion(item)
        elseif Tasks.AddText(popup.addTo, text, popup.place) then
            clearEntry()
        end
    elseif popup.onSubmit(text) == false then
        Style.SetBorderColor(popup.edit, "error")
    elseif not popup.addTo then  -- onSubmit may have moved on to adding entries
        close()
    end
end

local function createPopup()
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    p:SetWidth(WIDTH)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:Hide()
    Style.Fill(p, "bg")
    Style.Border(p)
    popup = p

    p.title = Style.Text(p, 13, "accent")
    p.title:SetPoint("TOPLEFT", PAD, -PAD)
    p.title:SetPoint("RIGHT", -28, 0)
    p.title:SetJustifyH("LEFT")
    p.title:SetWordWrap(false)

    local closeButton = CreateFrame("Button", nil, p)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", -6, -6)
    closeButton.text = Style.Text(closeButton, 13, "muted")
    closeButton.text:SetPoint("CENTER")
    closeButton.text:SetText("x")
    closeButton:SetScript("OnClick", close)

    p.edit = newField(p, WIDTH - 2 * PAD)
    p.edit:SetPoint("TOPLEFT", PAD, -PAD - 22)
    p.edit:SetAltArrowKeyMode(false)
    addStepper(p.edit)
    p.amount = newField(p, AMOUNT_W)
    p.amount:SetNumeric(true)
    p.amount:SetMaxLetters(4)
    p.amount:SetJustifyH("CENTER")
    p.amount:SetAltArrowKeyMode(false)
    p.amount:SetTextInsets(6, STEPPER_W + 2, 0, 0)
    addStepper(p.amount)
    p.amount:SetPoint("TOPRIGHT", -PAD, -PAD - 22)

    p.hint = Style.Text(p, 11, "muted")
    p.hint:SetPoint("TOPLEFT", p.edit, "BOTTOMLEFT", 0, -6)
    p.hint:SetWidth(WIDTH - 2 * PAD)
    p.hint:SetJustifyH("LEFT")

    p.ok = ns.Widgets.Button(p, { text = L.TASK_OK, width = OK_W, onClick = submit })
    p.ok:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    p.list = CreateFrame("Frame", nil, p)
    p.list:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, 1)
    p.list:SetWidth(WIDTH)
    Style.Fill(p.list, "bg")
    Style.Border(p.list)
    p.rows, p.results = {}, {}

    p.edit:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        Style.SetBorderColor(self, "border")
        if p.addTo then
            showSuggestions(Tasks.Search(self:GetText()))
        elseif p.zones then
            showSuggestions(Tasks.SearchZones(self:GetText()))
        end
    end)
    local function arrowStep(key) return key == "UP" and 1 or key == "DOWN" and -1 or nil end
    p.edit:SetScript("OnArrowPressed", function(self, key)
        local step = arrowStep(key)
        if not step then return end
        if p.numeric then stepAmount(self, step) else moveSelection(-step) end
    end)
    p.amount:SetScript("OnArrowPressed", function(self, key)
        local step = arrowStep(key)
        if step then stepAmount(self, step) end
    end)
    p.edit:SetScript("OnTabPressed", function() if p.addTo then p.amount:SetFocus() end end)
    p.amount:SetScript("OnTabPressed", function() p.edit:SetFocus() end)
    p.amount:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    for _, field in ipairs({ p.edit, p.amount }) do
        field:SetScript("OnEnterPressed", submit)
        field:SetScript("OnEscapePressed", close)
    end
end

-- opts: title, text (what the field starts with), hint, onSubmit(text)
-- (false: refused), addTo (a list: the item and text mode), zones (suggest
-- zone names for the text).
local function open(opts)
    if not popup then createPopup() end
    popup.addTo, popup.onSubmit, popup.zones = opts.addTo, opts.onSubmit, opts.zones
    popup.place = nil
    popup.title:SetText(opts.title)
    popup.hint:SetText(opts.hint or "")
    popup.amount:SetShown(opts.addTo ~= nil)
    popup.edit:SetWidth(WIDTH - 2 * PAD - (opts.addTo and AMOUNT_W + 6 or 0))
    popup.numeric = opts.numeric and true or false
    popup.edit:SetNumeric(popup.numeric)
    popup.edit:SetTextInsets(6, popup.numeric and STEPPER_W + 2 or 6, 0, 0)
    popup.edit.stepUp:SetShown(popup.numeric)
    popup.edit.stepDown:SetShown(popup.numeric)
    popup.edit:SetText(opts.text or "")
    popup.amount:SetText("1")
    Style.SetBorderColor(popup.edit, "border")
    showSuggestions({})
    popup:SetHeight(PAD + 22 + FIELD_H + 6 + (opts.hint and popup.hint:GetStringHeight() or 0) + OK_GAP + OK_H + PAD)
    popup:Show()
    popup.edit:SetFocus()
    popup.edit:HighlightText()
    return popup
end

function TaskUI.OpenAdd(list)
    return open({ title = L.TASK_PROMPT_ADD:format(list.name), hint = L.TASK_HINT, addTo = list })
end

function TaskUI.OpenNewList()
    return open({ title = L.TASK_PROMPT_NEW, onSubmit = function(text)
        local list = Tasks.AddList(text)
        if not list then return false end
        TaskUI.OpenAdd(list)  -- a new list is there to be filled
    end })
end

local function openRename(list)
    open({ title = L.TASK_PROMPT_RENAME, text = list.name, onSubmit = function(text)
        return Tasks.RenameList(list, text)
    end })
end

local function openEdit(entry)
    return open({ title = L.TASK_PROMPT_EDIT, text = entry.text, zones = true, onSubmit = function(text)
        return Tasks.SetText(entry, text, popup.place)
    end })
end

TaskUI.OpenEdit = openEdit

local function openAmount(entry)
    return open({ title = L.TASK_PROMPT_AMOUNT:format(entry.name), text = tostring(entry.goal), numeric = true,
        onSubmit = function(text) return Tasks.SetAmount(entry, text) end })
end

-- Menus ---------------------------------------------------------------------

-- Asks first: this takes all the entries with it.
local DELETE_DIALOG = "FOREVERQUESTLOG_TASK_LIST_DELETE"
StaticPopupDialogs[DELETE_DIALOG] = {
    text = "",
    button1 = DELETE or "Delete",
    button2 = CANCEL or "Cancel",
    OnAccept = function(_, list)
        if popup and popup:IsShown() and popup.addTo == list then close() end
        Tasks.RemoveList(list)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, exclusive = true,
}

TaskUI.OpenAmount = openAmount

function TaskUI.ListMenu(owner, list)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(list.name)
        root:CreateButton(L.TASK_RENAME, function() openRename(list) end)
        root:CreateButton(L.TASK_REMOVE_DONE, function() Tasks.RemoveDone(list) end)
        -- Undocking is the symbol beside the + (Rows.lua).
        if list.undocked then root:CreateButton(L.TASK_DOCK, function() Tasks.Dock(list) end) end
        root:CreateButton(L.TASK_DELETE_LIST, function()
            StaticPopupDialogs[DELETE_DIALOG].text = L.POPUP_TASK_LIST_DELETE
            StaticPopup_Show(DELETE_DIALOG, list.name, nil, list)
        end)
    end)
end

function TaskUI.EntryMenu(owner, list, entry)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if entry.itemID then
            root:CreateButton(L.TASK_CHANGE_AMOUNT, function() TaskUI.OpenAmount(entry) end)
        else
            root:CreateButton(L.TASK_EDIT, function() openEdit(entry) end)
        end
        local mapID = entry.place and entry.place.mapID
        if mapID then
            root:CreateButton(L.TASK_SHOW_MAP, function() ns.Actions.OpenMap(mapID) end)
        end
        root:CreateButton(L.TASK_REMOVE, function() Tasks.RemoveEntry(list, entry) end)
    end)
end
