local ADDON, ns = ...
local L, Settings, Media, Rows, Items = ns.L, ns.Settings, ns.Media, ns.Rows, ns.Items
local S = Settings.Get

-- The tracker frame: a header bar with the buttons, a scrolling list of
-- rows, a resize grip. Ordinary (insecure) frames only; the quest item
-- buttons are separate (Items.lua).
local Tracker = {}
ns.Tracker = Tracker

local HEADER_H = 32
local BUTTON = 22
local ACCENT = { 0.31, 0.76, 0.97 }          -- the options' blue: unlocked
local IDLE = { 0.73, 0.64, 0.48 }
local HOVER = { 1, 0.88, 0.54 }
local ON = { 1, 0.82, 0.29 }
local OFF = { 0.45, 0.42, 0.36 }
local WHEEL_STEP = 40
local GRIP = 16

local frame, header, scroll, child, grip, outline, readout, empty
local zoneRows, questRows = {}, {}
local refreshQueued, layoutPending = false, false
local resizing          -- { w0, h0, x0, y0 } while the grip is dragged
local lastShape         -- what the rows look like, to see whether combat may relayout
local content, view = 0, 0  -- the list's height and the part that shows
local chipRow = 0       -- the chip's own line under the header; 0 while it fits in it
local CHIP_ROW = 22

-- The header and, when the chip did not fit into it, the chip's line.
local function topHeight() return HEADER_H + chipRow end

local function screenSize()
    return UIParent:GetWidth(), UIParent:GetHeight()
end

local function state() return ns.CharState() end

-- Instances -----------------------------------------------------------------

-- The instance the player is in (a dungeon or raid), else nil.
function Tracker.Instance()
    local inside, kind = IsInInstance()
    if not inside or (kind ~= "party" and kind ~= "raid") then return nil end
    local name = GetInstanceInfo()
    return name, kind
end

-- Called on every PLAYER_ENTERING_WORLD: entering collapses once (when set)
-- and remembers how it was; leaving restores that. A /reload inside keeps
-- whatever the player chose there.
function Tracker.UpdateInstance()
    local st = state()
    local name = Tracker.Instance()
    if name and st.instance ~= name then
        st.instance = name
        st.onlyHere = S("instanceOnlyHere")
        if S("instanceCollapse") then
            st.beforeInstance = st.collapsed and true or false
            st.collapsed = true
        else
            st.beforeInstance = nil
        end
    elseif not name and st.instance then
        st.instance, st.onlyHere = nil, nil
        if st.beforeInstance ~= nil then st.collapsed = st.beforeInstance end
        st.beforeInstance = nil
    end
end

-- Placement -----------------------------------------------------------------

local function verticalPoint() return S("grow") == "UP" and "BOTTOM" or "TOP" end

-- The saved point, with its vertical half following the grow direction.
-- The saved point, its vertical half following the grow direction. A
-- centred one (set by the X / Y sliders) has no side.
local function anchorPoint()
    local point = S("point")
    local h = point:find("LEFT") and "LEFT" or (point:find("RIGHT") and "RIGHT" or "")
    return verticalPoint() .. h, h
end
Tracker.VerticalPoint = verticalPoint

local function place()
    if frame.moving then return end
    local point = anchorPoint()
    local s = S("scale") / 100
    frame:SetScale(s)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, S("x") / s, S("y") / s)
end

-- After dragging: the point from the side of the screen the frame is on,
-- the offsets in UIParent units.
local function savePosition()
    local s = frame:GetScale()
    local left, right = frame:GetLeft() * s, frame:GetRight() * s
    local top, bottom = frame:GetTop() * s, frame:GetBottom() * s
    local sw, sh = screenSize()
    local h = ((left + right) / 2 < sw / 2) and "LEFT" or "RIGHT"
    local v = verticalPoint()
    local x = (h == "LEFT") and left or (right - sw)
    local y = (v == "TOP") and (top - sh) or bottom
    Settings.SetMany({ point = v .. h, x = math.floor(x + 0.5), y = math.floor(y + 0.5) })
end

local function canMove()
    return not S("locked") or IsControlKeyDown()
end

-- Header ----------------------------------------------------------------------

local function paint(button, color)
    button.icon:SetVertexColor(color[1], color[2], color[3])
end

local function buttonColor(b)
    if b.isActive and b.isActive() then return b.activeColor or ON end
    if b.isActive then return OFF end
    return IDLE
end

local function headerButton(icon, tooltip, onClick, isActive)
    local b = CreateFrame("Button", nil, header)
    b:SetSize(BUTTON, BUTTON)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(Media.Icon(icon))
    b.tooltip, b.isActive = tooltip, isActive
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(self, mouse) onClick(self, mouse) end)
    b:SetScript("OnEnter", function(self)
        paint(self, HOVER)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local text = type(self.tooltip) == "function" and self.tooltip() or self.tooltip
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        paint(self, buttonColor(self))
        GameTooltip:Hide()
    end)
    paint(b, buttonColor(b))
    return b
end

-- The instance chip: "This dungeon" / "All quests".
local function newChip()
    local chip = CreateFrame("Button", nil, header)
    chip:SetHeight(16)
    chip.text = chip:CreateFontString(nil, "OVERLAY")
    chip.text:SetPoint("CENTER", 0, 0)
    chip.edges = {}
    for i = 1, 4 do chip.edges[i] = chip:CreateTexture(nil, "ARTWORK") end
    chip.edges[1]:SetPoint("TOPLEFT"); chip.edges[1]:SetPoint("TOPRIGHT"); chip.edges[1]:SetHeight(1)
    chip.edges[2]:SetPoint("BOTTOMLEFT"); chip.edges[2]:SetPoint("BOTTOMRIGHT"); chip.edges[2]:SetHeight(1)
    chip.edges[3]:SetPoint("TOPLEFT"); chip.edges[3]:SetPoint("BOTTOMLEFT"); chip.edges[3]:SetWidth(1)
    chip.edges[4]:SetPoint("TOPRIGHT"); chip.edges[4]:SetPoint("BOTTOMRIGHT"); chip.edges[4]:SetWidth(1)
    chip.fill = chip:CreateTexture(nil, "BACKGROUND")
    chip.fill:SetAllPoints()
    chip:SetScript("OnClick", function()
        local st = state()
        st.onlyHere = not st.onlyHere
        st.collapsed = false
        Tracker.Refresh()
    end)
    chip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.TIP_ONLY_HERE, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return chip
end

-- Right after the count; when the header is too narrow for that, on a line
-- of its own under it, so it never covers the count or the buttons.
local function layoutChip()
    local chip = header.chip
    local st = state()
    chipRow = 0
    if not st.instance then
        chip:Hide()
        return
    end
    local on = st.onlyHere and true or false
    chip.text:SetFont(Media.FontPath(S("objectiveFont")), 11, "")
    chip.text:SetText(on and L.CHIP_THIS_DUNGEON or L.CHIP_ALL_QUESTS)
    local c = on and ACCENT or { 0.6, 0.57, 0.51 }
    chip.text:SetTextColor(c[1], c[2], c[3])
    for _, e in ipairs(chip.edges) do e:SetColorTexture(c[1], c[2], c[3], on and 0.6 or 0.35) end
    chip.fill:SetColorTexture(c[1], c[2], c[3], on and 0.12 or 0)
    local width = chip.text:GetStringWidth() + 14
    chip:SetWidth(width)

    local titleLeft = S("locked") and 10 or 26
    local countRight = titleLeft + header.title:GetStringWidth() + 6 + header.count:GetStringWidth()
    -- Five buttons from the right edge, 5 px in, 1 px apart.
    local buttonsLeft = S("width") - 5 - 5 * BUTTON - 4
    chip:ClearAllPoints()
    if countRight + 8 + width + 4 <= buttonsLeft then
        chip:SetPoint("LEFT", header, "LEFT", countRight + 8, 0)
    else
        chip:SetPoint("TOPLEFT", header, "BOTTOMLEFT", titleLeft, -3)
        chipRow = CHIP_ROW
    end
    chip:Show()
end

local function toggleCollapse()
    local st = state()
    st.collapsed = not st.collapsed
    st.combatCollapsed = nil
    Tracker.Refresh()
end

local function createHeader()
    header = CreateFrame("Button", nil, frame)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:RegisterForClicks("LeftButtonUp")
    header:EnableMouse(true)
    header.shine = header:CreateTexture(nil, "BACKGROUND", nil, 1)
    header.shine:SetAllPoints()
    header.shine:SetColorTexture(1, 1, 1, 1)
    header.shine:SetGradient("VERTICAL", CreateColor(1, 0.79, 0.19, 0), CreateColor(1, 0.79, 0.19, 0.10))
    header.line = header:CreateTexture(nil, "ARTWORK")
    header.line:SetHeight(1)
    header.line:SetPoint("BOTTOMLEFT")
    header.line:SetPoint("BOTTOMRIGHT")
    header.line:SetColorTexture(0.78, 0.59, 0.13, 0.45)

    header.grip = header:CreateTexture(nil, "OVERLAY")
    header.grip:SetSize(12, 12)
    header.grip:SetPoint("LEFT", 8, 0)
    header.grip:SetTexture(Media.Icon("Grip"))
    header.grip:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])

    header.title = header:CreateFontString(nil, "OVERLAY")
    header.count = header:CreateFontString(nil, "OVERLAY")
    header.count:SetPoint("BOTTOMLEFT", header.title, "BOTTOMRIGHT", 6, 1)
    -- Hovering the count tells how many of the quests are tracked.
    header.countHover = CreateFrame("Frame", nil, header)
    header.countHover:SetAllPoints(header.count)
    header.countHover:EnableMouse(true)
    header.countHover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.TIP_COUNT:format(self.inLog or 0, self.max or 0), 1, 1, 1)
        GameTooltip:AddLine(L.TIP_TRACKED:format(self.tracked or 0), nil, nil, nil, true)
        GameTooltip:Show()
    end)
    header.countHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Right to left.
    local collapse = headerButton("ChevronUp", function()
        return state().collapsed and L.TIP_EXPAND or L.TIP_COLLAPSE
    end, toggleCollapse)
    local options = headerButton("Gear", L.TIP_OPTIONS, function() ns.Window.Toggle() end)
    local lock = headerButton("Lock", function()
        return S("locked") and L.TIP_UNLOCK or L.TIP_LOCK
    end, function() Settings.SetLocked(not S("locked")) end)
    local sort = headerButton("SortWatch", function()
        return S("sortBy") == "LEVEL" and L.TIP_SORT_LEVEL or L.TIP_SORT_WATCH
    end, function() Settings.Set("sortBy", S("sortBy") == "LEVEL" and "WATCH" or "LEVEL") end)
    local zones = headerButton("Zones", function()
        return S("groupByZone") and L.TIP_ZONES_ON or L.TIP_ZONES_OFF
    end, function() Settings.Set("groupByZone", not S("groupByZone")) end,
        function() return S("groupByZone") end)
    header.collapse, header.options, header.lock, header.sort, header.zones = collapse, options, lock, sort, zones
    collapse:SetPoint("RIGHT", -5, 0)
    options:SetPoint("RIGHT", collapse, "LEFT", -1, 0)
    lock:SetPoint("RIGHT", options, "LEFT", -1, 0)
    sort:SetPoint("RIGHT", lock, "LEFT", -1, 0)
    zones:SetPoint("RIGHT", sort, "LEFT", -1, 0)
    header.chip = newChip()

    -- Dragging the header moves the frame (unlocked, or with Ctrl).
    header:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" and canMove() then
            frame:StartMoving()
            frame.moving = true
        end
    end)
    header:SetScript("OnMouseUp", function()
        if frame.moving then
            frame:StopMovingOrSizing()
            frame.moving = nil
            savePosition()
        end
    end)
end

-- The count reads like the quest log's: quests in the log / its maximum,
-- red when over it; the tracked number is in the tooltip.
local function layoutHeader(tracked)
    local inLog, max = ns.Data.LogCount()
    local unlocked = not S("locked")
    Media.ApplyText(header.title, Settings.TextStyle("header"))
    header.title:SetText(L.HEADER_QUESTS)
    header.title:ClearAllPoints()
    header.title:SetPoint("LEFT", unlocked and 26 or 10, 0)
    header.grip:SetShown(unlocked)
    local countStyle = Settings.TextStyle("objective")
    countStyle.size = math.max(8, S("headerSize") - 3)
    countStyle.flag = ""
    countStyle.color = { 0.56, 0.54, 0.5 }
    Media.ApplyText(header.count, countStyle)
    local full = max > 0 and inLog >= max
    header.count:SetText((full and "|cffff4040" or "") .. inLog .. " / " .. max .. (full and "|r" or ""))
    header.countHover.inLog, header.countHover.max, header.countHover.tracked = inLog, max, tracked
    header.line:SetShown(S("headerLine") and not state().collapsed)
    header.collapse.icon:SetTexture(Media.Icon(state().collapsed and "ChevronDown" or "ChevronUp"))
    header.lock.icon:SetTexture(Media.Icon(S("locked") and "Lock" or "Unlock"))
    header.lock.activeColor = ACCENT
    header.lock.isActive = function() return not S("locked") end
    header.sort.icon:SetTexture(Media.Icon(S("sortBy") == "LEVEL" and "SortLevel" or "SortWatch"))
    for _, b in ipairs({ header.collapse, header.options, header.lock, header.sort, header.zones }) do
        paint(b, b.isActive and buttonColor(b) or IDLE)
    end
    if not S("locked") then paint(header.lock, ACCENT) end
    layoutChip()
end

-- Background and border -------------------------------------------------------

local function applyLook()
    Media.ApplyBackground(frame.bg, S("bgMode"), S("bgColor"), S("bgAlpha") / 100, S("bgTexture"))
    local w, h = frame:GetWidth(), frame:GetHeight()
    local radius = ns.Corners.Clamp(S("cornerRadius"), w, h)
    ns.Corners.Fit(frame.clip, frame, radius, { frame.bg, header.shine })
    ns.Border.Draw(frame, frame, {
        style = S("borderStyle"), size = S("borderSize"), color = S("borderColor"), radius = radius,
        shadow = S("shadowEnabled"), shadowSize = S("shadowSize"), shadowAlpha = S("shadowAlpha") / 100,
    })
end

-- Unlocked: a blue outline, the grip and the size below the frame.
local function layoutUnlocked()
    local unlocked = not S("locked")
    for _, e in ipairs(outline) do e:SetShown(unlocked) end
    grip:SetShown(unlocked)
    readout:SetShown(unlocked or resizing ~= nil)
    if not unlocked then return end
    -- The grip sits in the corner opposite the anchor: that corner moves.
    local point, side = anchorPoint()
    local v = point:find("TOP") and "BOTTOM" or "TOP"
    local h = side == "LEFT" and "RIGHT" or "LEFT"
    grip:ClearAllPoints()
    grip:SetPoint(v .. h, frame, v .. h, 0, 0)
    local flipX, flipY = h == "LEFT", v == "TOP"
    grip.icon:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
    readout:ClearAllPoints()
    if v == "BOTTOM" then
        readout:SetPoint("TOP", frame, "BOTTOM", 0, -8)
    else
        readout:SetPoint("BOTTOM", frame, "TOP", 0, 8)
    end
    readout.text:SetText(("%d x %d  ·  %s"):format(S("width"), math.floor(frame:GetHeight() + 0.5), L.UNLOCKED_HINT))
    readout:SetWidth(readout.text:GetStringWidth() + 16)
end

-- Rows -------------------------------------------------------------------------

local function acquire(pool, n, make)
    local row = pool[n]
    if not row then
        row = make(child)
        pool[n] = row
    end
    row:Show()
    return row
end

local function release(pool, from)
    for i = from, #pool do pool[i]:Hide() end
end

local function toggleZone(name)
    local zones = state().zones
    zones[name] = not zones[name] or nil
    Tracker.Refresh()
end

local function toggleSection(key)
    local sections = state().sections
    sections[key] = not sections[key] or nil
    Tracker.Refresh()
end

-- The entries to draw: quests (grouped / sorted), then the recipes under
-- their own header.
function Tracker.Entries(quests, recipes)
    local st = state()
    local entries = ns.Sort.Build(quests, {
        sortBy = S("sortBy"),
        groupByZone = S("groupByZone"),
        currentZoneFirst = S("currentZoneFirst"),
        currentZone = GetRealZoneText and GetRealZoneText() or nil,
        collapsedZones = st.zones,
        onlyZone = st.instance and st.onlyHere and st.instance or nil,
    })
    if #recipes > 0 then
        local collapsed = st.sections.recipes and true or false
        entries[#entries + 1] = { kind = "section", key = "recipes", count = #recipes, collapsed = collapsed,
            name = PROFESSIONS_TRACKER_HEADER_PROFESSION or L.SECTION_RECIPES }
        if not collapsed then
            for _, r in ipairs(recipes) do entries[#entries + 1] = { kind = "recipe", recipe = r } end
        end
    end
    return entries
end

-- What the rows are: kinds and ids in order. In combat with item buttons
-- showing, rows may only change their texts, not move (the buttons cannot
-- follow); a new shape waits for the end of combat.
local function shapeOf(entries)
    local parts = {}
    for _, e in ipairs(entries) do
        if e.kind == "quest" then
            local q = e.quest
            local done = {}
            for _, line in ipairs(Rows.QuestLines(q)) do done[#done + 1] = line.done and "1" or "0" end
            parts[#parts + 1] = "q" .. q.id .. (q.isComplete and "c" or "") .. table.concat(done)
        elseif e.kind == "recipe" then
            parts[#parts + 1] = "r" .. e.recipe.id
        else
            parts[#parts + 1] = e.kind .. (e.name or "") .. (e.collapsed and "-" or "+")
        end
    end
    return table.concat(parts, ",")
end

-- Places the item buttons at their rows (out of combat), only for rows the
-- scroll area shows.
local function placeItems(itemRows)
    if InCombatLockdown() then return end
    local wanted = {}
    if frame:IsShown() and not state().collapsed then
        local us = UIParent:GetEffectiveScale()
        local top, bottom = scroll:GetTop(), scroll:GetBottom()
        for _, row in ipairs(itemRows) do
            local rTop = row:GetTop()
            if rTop and top and rTop <= top + 1 and rTop - Items.SIZE >= bottom - 1 then
                local es = row:GetEffectiveScale()
                wanted[#wanted + 1] = {
                    item = row.quest.item,
                    x = row:GetRight() * es / us,
                    y = rTop * es / us,
                    scale = frame:GetScale(),
                }
            end
        end
    end
    Items.Place(wanted)
end

local itemRows = {}

function Tracker.Layout()
    if not frame then return end
    Tracker.queued = false
    ns.Blizzard.Check()
    local quests = ns.Data.Quests()
    local recipes = S("showRecipes") and ns.Data.Recipes() or {}
    local entries = Tracker.Entries(quests, recipes)
    local st = state()

    local shape = shapeOf(entries)
    if InCombatLockdown() and Items.Count() > 0 and shape ~= lastShape and not st.collapsed then
        -- The list keeps showing the state from before until combat ends;
        -- clicks already act on the current quest data.
        layoutPending = true
        for _, row in ipairs(questRows) do
            if row:IsShown() and row.quest then
                for _, q in ipairs(quests) do
                    if q.id == row.quest.id then row.quest = q end
                end
            end
        end
        return
    end
    lastShape = shape

    local width = S("width")
    local pad = S("padding")
    frame:SetWidth(width)
    layoutHeader(#quests)

    local inner = width - 2 * pad
    -- The scroll area reaches to the frame's left edge and up to the header,
    -- so map buttons (wider than their column, with a glow when focused) are
    -- not cut off; the rows start `pad` in.
    child:SetWidth(inner + pad)
    local y, nz, nq = pad, 0, 0
    itemRows = {}
    local index = 0
    for i, e in ipairs(entries) do
        local row, h
        if e.kind == "zone" or e.kind == "section" then
            nz = nz + 1
            row = acquire(zoneRows, nz, Rows.NewZoneRow)
            if e.kind == "zone" then
                h = Rows.LayoutZone(row, e, inner, e.name, toggleZone)
            else
                h = Rows.LayoutZone(row, e, inner, e.key, toggleSection)
            end
            if i > 1 then y = y + 4 end
        else
            nq = nq + 1
            row = acquire(questRows, nq, Rows.NewQuestRow)
            local wantsItem
            if e.kind == "quest" then
                index = index + 1
                h, wantsItem = Rows.LayoutQuest(row, e.quest, inner, index)
            else
                h = Rows.LayoutRecipe(row, e.recipe, inner)
            end
            if wantsItem then itemRows[#itemRows + 1] = row end
            if i > 1 then y = y + S("questSpacing") end
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", child, "TOPLEFT", pad, -y)
        y = y + h
    end
    release(zoneRows, nz + 1)
    release(questRows, nq + 1)

    local unlocked = not S("locked")
    empty:SetShown(#entries == 0)
    if #entries == 0 then y = pad + 20 end
    child:SetHeight(math.max(1, y))

    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -chipRow)
    local bodyMax = S("height") - topHeight() - pad
    local body = (S("fitContent") and not resizing) and math.min(y, bodyMax) or bodyMax
    if st.collapsed then
        scroll:Hide()
        frame:SetHeight(topHeight())
    else
        scroll:Show()
        frame:SetHeight(topHeight() + pad + math.max(body, 20))
    end
    content, view = y, math.max(body, 20)
    local range = math.max(0, y - body)
    if (scroll:GetVerticalScroll() or 0) > range then scroll:SetVerticalScroll(range) end
    Tracker.UpdateScrollbar()

    -- Nothing tracked and locked: out of the way, as Blizzard's tracker.
    local visible = #entries > 0 or unlocked or (st.instance and st.onlyHere and #quests > 0)
    frame:SetShown(visible and true or false)
    place()
    applyLook()
    layoutUnlocked()
    placeItems(itemRows)
    Tracker.UpdateAlpha()
    layoutPending = false
end

-- Many events come in bursts: one layout on the next frame.
function Tracker.Refresh()
    if not frame or Tracker.queued then return end
    Tracker.queued = true
    C_Timer.After(0, Tracker.Layout)
end

-- Scrolling -------------------------------------------------------------------

-- From the layout's own numbers (content and visible height, set in
-- Layout), not the frames' measured heights: those are snapped to pixels,
-- and the leftover pixel or two showed a bar almost as tall as the list
-- with nothing to scroll.
function Tracker.UpdateScrollbar()
    local thumb = frame.thumb
    local range = content - view
    if range < 2 or view <= 0 or state().collapsed then thumb:Hide(); return end
    local thumbH = math.max(16, view * view / (view + range))
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", S("padding") - 3, -(view - thumbH) * (scroll:GetVerticalScroll() or 0) / range)
    thumb:Show()
end

local function onWheel(_, delta)
    -- Item buttons cannot follow in combat.
    if InCombatLockdown() and Items.Count() > 0 then return end
    local range = math.max(0, content - view)
    local v = (scroll:GetVerticalScroll() or 0) - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(range, v)))
    Tracker.UpdateScrollbar()
    placeItems(itemRows)
end

-- Resizing ------------------------------------------------------------------

local function cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

local function onResizeUpdate()
    if not resizing then return end
    local x, y = cursor()
    local s = frame:GetScale()
    local dx, dy = (x - resizing.x0) / s, (y - resizing.y0) / s
    local point, side = anchorPoint()
    local w = resizing.w0 + (side == "LEFT" and dx or -dx)
    local h = resizing.h0 + (point:find("TOP") and -dy or dy)
    local r1, r2 = Settings.RANGES.width, Settings.RANGES.height
    w = math.max(r1[1], math.min(r1[2], math.floor(w + 0.5)))
    h = math.max(r2[1], math.min(r2[2], math.floor(h + 0.5)))
    if w ~= resizing.w or h ~= resizing.h then
        resizing.w, resizing.h = w, h
        ns.DB().width, ns.DB().height = w, h
        Tracker.Layout()
    end
end

local function createGrip()
    grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP, GRIP)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip.icon = grip:CreateTexture(nil, "OVERLAY")
    grip.icon:SetAllPoints()
    grip.icon:SetTexture(Media.Icon("Resize"))
    grip.icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
    grip:SetScript("OnMouseDown", function()
        -- From a centred anchor the frame would grow both ways: a corner first.
        if select(2, anchorPoint()) == "" then savePosition(); place() end
        local x, y = cursor()
        resizing = { w0 = S("width"), h0 = math.max(S("height"), frame:GetHeight()), x0 = x, y0 = y }
        grip:SetScript("OnUpdate", onResizeUpdate)
    end)
    grip:SetScript("OnMouseUp", function()
        grip:SetScript("OnUpdate", nil)
        if not resizing then return end
        local w, h = ns.DB().width or S("width"), ns.DB().height or S("height")
        local values = { width = w, height = h }
        -- Dragged taller than the content: the size the player chose stays,
        -- instead of snapping back to the content.
        if S("fitContent") and h > content + topHeight() + S("padding") + 2 and math.abs(h - resizing.h0) > 2 then
            values.fitContent = false
        end
        resizing = nil
        Settings.SetMany(values)
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.TIP_RESIZE, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Fading --------------------------------------------------------------------

function Tracker.UpdateAlpha()
    if not frame then return end
    local alpha = 1
    if S("locked") and not frame:IsMouseOver() and not (frame.moving or resizing) then
        alpha = S("fadeAlpha") / 100
    end
    frame:SetAlpha(alpha)
    Items.SetAlpha(state().collapsed and 0 or alpha)
end

local elapsedSince = 0
local function onUpdate(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.1 then return end
    elapsedSince = 0
    Tracker.UpdateAlpha()
end

-- Building --------------------------------------------------------------------

local function createOutline()
    outline = {}
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
        outline[i] = t
    end
    local o = 5
    outline[1]:SetPoint("TOPLEFT", -o, o); outline[1]:SetPoint("TOPRIGHT", o, o); outline[1]:SetHeight(1)
    outline[2]:SetPoint("BOTTOMLEFT", -o, -o); outline[2]:SetPoint("BOTTOMRIGHT", o, -o); outline[2]:SetHeight(1)
    outline[3]:SetPoint("TOPLEFT", -o, o); outline[3]:SetPoint("BOTTOMLEFT", -o, -o); outline[3]:SetWidth(1)
    outline[4]:SetPoint("TOPRIGHT", o, o); outline[4]:SetPoint("BOTTOMRIGHT", o, -o); outline[4]:SetWidth(1)

    readout = CreateFrame("Frame", nil, frame)
    readout:SetHeight(18)
    local bg = readout:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.055, 0.07, 0.9)
    readout.text = readout:CreateFontString(nil, "OVERLAY")
    readout.text:SetFont(Media.FontPath("Arial Narrow"), 12, "")
    readout.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    readout.text:SetPoint("CENTER")
end

function Tracker.Build()
    if frame or S("useBlizzard") then return end
    frame = CreateFrame("Frame", "ForeverQuestLogFrame", UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    -- The position is ours (Settings); the client's layout cache stays out.
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    frame:SetSize(S("width"), S("height"))
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.clip = {}
    createHeader()
    scroll = CreateFrame("ScrollFrame", "ForeverQuestLogScroll", frame)
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S("padding"), S("padding"))
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    frame.thumb = frame:CreateTexture(nil, "OVERLAY")
    frame.thumb:SetWidth(2)
    frame.thumb:SetColorTexture(0.55, 0.41, 0.1, 0.9)
    empty = child:CreateFontString(nil, "OVERLAY")
    empty:SetPoint("TOPLEFT", S("padding"), -S("padding"))
    empty:SetFont(Media.FontPath("Arial Narrow"), 13, "")
    empty:SetTextColor(0.6, 0.58, 0.54)
    empty:SetText(L.EMPTY)
    createGrip()
    createOutline()
    frame:SetScript("OnUpdate", onUpdate)
    Tracker.frame = frame
    Tracker.UpdateInstance()
    Tracker.Layout()
end

-- Re-anchors the scroll area when the padding changes.
local function applyPadding()
    if not scroll then return end
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -chipRow)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S("padding"), S("padding"))
end

Settings.OnChange(function(key)
    if not frame then return end
    if key == nil or key == "padding" then applyPadding() end
    if key == "minimapShow" or key == "minimapAngle" then return end
    Tracker.Refresh()
end)

-- Events ----------------------------------------------------------------------

local REFRESH_EVENTS = {
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_AUTOCOMPLETE", "SUPER_TRACKING_CHANGED",
    "QUEST_TURNED_IN", "QUEST_POI_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_MONEY",
    "TRACKED_RECIPE_UPDATE", "BAG_UPDATE_DELAYED", "CURRENCY_DISPLAY_UPDATE", "GET_ITEM_INFO_RECEIVED",
    "UNIT_QUEST_LOG_CHANGED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
}
for _, event in ipairs(REFRESH_EVENTS) do ns.On(event, function() Tracker.Refresh() end) end

ns.On("PLAYER_LOGIN", function()
    ns.RebuildPresets()
    Tracker.Build()
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    if not frame then return end
    Tracker.UpdateInstance()
    Tracker.Refresh()
end)

-- Combat: collapse when set (still allowed here: the lockdown starts after
-- this event), and catch up on what waited.
ns.On("PLAYER_REGEN_DISABLED", function()
    if not frame then return end
    local st = state()
    if S("combatCollapse") and not st.collapsed then
        st.collapsed, st.combatCollapsed = true, true
        Tracker.Layout()
    end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    if not frame then return end
    local st = state()
    if st.combatCollapsed then
        st.collapsed, st.combatCollapsed = false, nil
    end
    lastShape = nil
    Tracker.Layout()
end)

function Tracker.IsLayoutPending() return layoutPending end

-- Right under the minimap, its right edges in line.
function Tracker.SnapBelowMinimap()
    local map = _G.Minimap
    if not (map and map:GetRight()) then return end
    local scale = map:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local sw, sh = screenSize()
    local right, bottom = map:GetRight() * scale, map:GetBottom() * scale
    Settings.SetMany({ point = "TOPRIGHT", grow = "DOWN", x = math.floor(right - sw + 0.5), y = math.floor(bottom - sh - 16 + 0.5) })
end
