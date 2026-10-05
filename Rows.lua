local ADDON, ns = ...
local L, Settings, Media = ns.L, ns.Settings, ns.Media
local S = Settings.Get

-- The rows of the list: zone / section headers, quests and recipes. Each
-- row lays itself out for a width and returns its height; Tracker.lua
-- stacks them. Rows are pooled per kind and never destroyed.
local Rows = {}
ns.Rows = Rows

Rows.POI_W = 22         -- room for Blizzard's map button
Rows.ITEM_W = 30        -- room for a quest item button
Rows.ZONE_H = 22
local LINE_GAP = 3      -- between title and objectives, and between lines
local BAR_GAP = 2       -- between an objective and its bar
local COUNT_GAP = 6
local TAG_PAD = 4

local function hex(c)
    return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- Lines (an objective: text, count, bar) -----------------------------------

local function newLine(parent)
    local line = {}
    line.text = parent:CreateFontString(nil, "OVERLAY")
    line.text:SetJustifyH("LEFT")
    line.text:SetJustifyV("TOP")
    line.text:SetWordWrap(true)
    line.count = parent:CreateFontString(nil, "OVERLAY")
    line.count:SetJustifyH("RIGHT")
    line.icon = parent:CreateTexture(nil, "OVERLAY")
    line.icon:SetTexture(Media.Icon("Check"))
    line.icon:SetSize(12, 12)
    line.barBg = parent:CreateTexture(nil, "ARTWORK")
    line.bar = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    return line
end

local function hideLine(line)
    line.text:Hide(); line.count:Hide(); line.icon:Hide(); line.barBg:Hide(); line.bar:Hide()
end

-- One line at (x, -y) of row, width w. o: { text, cur, max, done, percent }
-- or a plain text line with a style ("done", "failed"). Returns its height.
local function layoutLine(row, line, o, x, y, w, style)
    local isDone = o.done
    local textStyle = Settings.TextStyle(style or "objective")
    if style == nil and isDone then textStyle.color = S("objectiveDoneColor") end
    if o.color then textStyle.color = o.color end
    local countText
    if o.percent then
        countText = math.floor(o.percent + 0.5) .. "%"
    elseif o.cur and o.max then
        countText = o.cur .. "/" .. o.max
    end
    local left = x
    if o.check then
        line.icon:ClearAllPoints()
        line.icon:SetPoint("TOPLEFT", row, "TOPLEFT", x, -y - 1)
        local c = textStyle.color
        line.icon:SetVertexColor(c[1], c[2], c[3])
        line.icon:Show()
        left = x + 15
    else
        line.icon:Hide()
    end
    local countW = 0
    if countText then
        Media.ApplyText(line.count, textStyle)
        line.count:SetText(countText)
        countW = line.count:GetStringWidth()
        line.count:ClearAllPoints()
        line.count:SetPoint("TOPRIGHT", row, "TOPLEFT", x + w, -y)
        line.count:Show()
    else
        line.count:Hide()
    end
    Media.ApplyText(line.text, textStyle)
    local textW = w - (left - x) - (countText and (countW + COUNT_GAP) or 0)
    line.text:SetWidth(math.max(20, textW))
    line.text:SetText(o.text or "")
    line.text:ClearAllPoints()
    line.text:SetPoint("TOPLEFT", row, "TOPLEFT", left, -y)
    line.text:Show()
    local h = math.max(line.text:GetStringHeight(), countText and line.count:GetStringHeight() or 0)
    local showBar = S("showBars") and not isDone and (o.percent or (o.max and o.max > 1))
    if showBar then
        local barH = S("barHeight")
        local by = y + h + BAR_GAP
        line.barBg:ClearAllPoints()
        line.barBg:SetPoint("TOPLEFT", row, "TOPLEFT", left, -by)
        line.barBg:SetSize(w - (left - x), barH)
        line.barBg:SetColorTexture(1, 1, 1, S("barBgAlpha") / 100)
        line.barBg:Show()
        local share = o.percent and (o.percent / 100) or ((o.cur or 0) / o.max)
        share = math.max(0, math.min(1, share))
        if share > 0 then
            local c = S("barColor")
            line.bar:ClearAllPoints()
            line.bar:SetPoint("TOPLEFT", line.barBg, "TOPLEFT", 0, 0)
            line.bar:SetSize(math.max(1, (w - (left - x)) * share), barH)
            line.bar:SetTexture(Media.Path("statusbar", S("barTexture")))
            line.bar:SetVertexColor(c[1], c[2], c[3], 1)
            line.bar:Show()
        else
            line.bar:Hide()
        end
        h = h + BAR_GAP + barH
    else
        line.barBg:Hide()
        line.bar:Hide()
    end
    return h
end

local function lines(row, n)
    row.lines = row.lines or {}
    for i = #row.lines + 1, n do row.lines[i] = newLine(row) end
    for i = n + 1, #row.lines do hideLine(row.lines[i]) end
    return row.lines
end

-- Hover ---------------------------------------------------------------------

local function newHover(row)
    local t = row:CreateTexture(nil, "BACKGROUND")
    t:SetPoint("TOPLEFT", -4, 3)
    t:SetPoint("BOTTOMRIGHT", 4, -3)
    t:SetColorTexture(1, 1, 1, 0.05)
    t:Hide()
    return t
end

-- Zone and section headers ---------------------------------------------------

local function newZoneRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp")
    row:EnableMouse(true)
    row.chevron = row:CreateTexture(nil, "OVERLAY")
    row.chevron:SetSize(10, 10)
    row.chevron:SetPoint("LEFT", 0, 0)
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("LEFT", row.chevron, "RIGHT", 5, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.count = row:CreateFontString(nil, "OVERLAY")
    row.count:SetPoint("RIGHT", 0, 0)
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    row.rule:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.rule:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row:SetScript("OnClick", function(self) if self.onToggle then self.onToggle(self.key) end end)
    row:SetScript("OnEnter", function(self) self.name:SetAlpha(1); self.chevron:SetAlpha(1) end)
    row:SetScript("OnLeave", function(self) self.name:SetAlpha(0.9); self.chevron:SetAlpha(0.8) end)
    return row
end

-- entry: { name, count, collapsed }, key: what onToggle gets.
function Rows.LayoutZone(row, entry, width, key, onToggle)
    row.key, row.onToggle = key, onToggle
    local style = Settings.TextStyle("zone")
    Media.ApplyText(row.name, style)
    Media.ApplyText(row.count, style)
    local c = style.color
    row.count:SetTextColor(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7)
    row.name:SetText(entry.name)
    row.name:SetWidth(0)
    local maxName = width - 60
    if row.name:GetStringWidth() > maxName then row.name:SetWidth(maxName) end
    row.count:SetText(entry.count or "")
    row.chevron:SetTexture(Media.Icon(entry.collapsed and "ChevronRight" or "ChevronDown"))
    row.chevron:SetVertexColor(c[1], c[2], c[3])
    row.rule:SetColorTexture(1, 1, 1, 1)
    row.rule:SetGradient("HORIZONTAL", CreateColor(0.78, 0.59, 0.13, 0.4), CreateColor(0.78, 0.59, 0.13, 0))
    row.name:SetAlpha(0.9)
    row.chevron:SetAlpha(0.8)
    local h = math.max(Rows.ZONE_H, row.name:GetStringHeight() + 8)
    row:SetSize(width, h)
    return h
end

-- Tags ----------------------------------------------------------------------

local function newTag(row)
    local tag = CreateFrame("Frame", nil, row)
    tag.text = tag:CreateFontString(nil, "OVERLAY")
    tag.text:SetPoint("CENTER", 0, 0)
    tag.edges = {}
    for i = 1, 4 do
        tag.edges[i] = tag:CreateTexture(nil, "ARTWORK")
        tag.edges[i]:SetColorTexture(1, 0.82, 0.29, 0.45)
    end
    tag.edges[1]:SetPoint("TOPLEFT"); tag.edges[1]:SetPoint("TOPRIGHT"); tag.edges[1]:SetHeight(1)
    tag.edges[2]:SetPoint("BOTTOMLEFT"); tag.edges[2]:SetPoint("BOTTOMRIGHT"); tag.edges[2]:SetHeight(1)
    tag.edges[3]:SetPoint("TOPLEFT"); tag.edges[3]:SetPoint("BOTTOMLEFT"); tag.edges[3]:SetWidth(1)
    tag.edges[4]:SetPoint("TOPRIGHT"); tag.edges[4]:SetPoint("BOTTOMRIGHT"); tag.edges[4]:SetWidth(1)
    return tag
end

local function layoutTag(tag, text, titleStyle)
    if not text then
        tag:Hide()
        return 0
    end
    tag.text:SetFont(Media.FontPath(titleStyle.font), math.max(8, titleStyle.size - 4), "")
    tag.text:SetTextColor(1, 0.82, 0.29)
    tag.text:SetText(text)
    local w = tag.text:GetStringWidth() + 2 * TAG_PAD
    tag:SetSize(w, tag.text:GetStringHeight() + 3)
    tag:Show()
    return w
end

-- POI button: Blizzard's own, so clicking super-tracks exactly as on the
-- map. Its template comes with Blizzard_POIButton; without it a plain
-- number stands in.
local function newPOI(row)
    local ok, button = pcall(CreateFrame, "Button", nil, row, "POIButtonTemplate")
    if ok and button and button.SetQuestID then return button end
    local plain = CreateFrame("Frame", nil, row)
    plain:SetSize(18, 18)
    plain.text = plain:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plain.text:SetPoint("CENTER")
    plain.isPlain = true
    return plain
end

local function layoutPOI(poi, quest, index)
    if poi.isPlain then
        poi.text:SetText(index or "")
        return
    end
    local style = POIButtonUtil and POIButtonUtil.Style
    if style then
        poi:SetQuestID(quest.id)
        poi:SetStyle(quest.isComplete and style.QuestComplete or style.QuestInProgress)
        poi:SetSelected(quest.superTracked)
        poi:UpdateButtonStyle()
    end
end

-- Quests --------------------------------------------------------------------

local function newQuestRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:EnableMouse(true)
    row.hover = newHover(row)
    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetJustifyH("LEFT")
    row.title:SetJustifyV("TOP")
    row.title:SetWordWrap(true)
    row.title:SetMaxLines(2)
    row.tag = newTag(row)
    row.poi = newPOI(row)
    row:SetScript("OnClick", function(self, button)
        if self.quest then ns.Actions.QuestClick(self, self.quest, button) end
        if self.recipe then ns.Actions.RecipeClick(self, self.recipe, button) end
    end)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        local tc = self.titleColor
        if tc then self.title:SetTextColor(1, 1, 1) end
        if self.quest then ns.Actions.QuestEnter(self, self.quest) end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        local tc = self.titleColor
        if tc then self.title:SetTextColor(tc[1], tc[2], tc[3]) end
        ns.Actions.Leave()
    end)
    return row
end

-- The objective lines of a quest, as Blizzard's tracker picks them
-- (UpdateSingle): complete quests show only how to turn them in, failed
-- ones "Failed", others the way point (super-tracked), the objectives and
-- money still missing.
function Rows.QuestLines(q)
    local list = {}
    if q.isComplete then
        if q.isAutoComplete then
            list[#list + 1] = { text = QUEST_WATCH_QUEST_COMPLETE or L.QUEST_COMPLETE, style = "done", check = true }
            list[#list + 1] = { text = QUEST_WATCH_CLICK_TO_COMPLETE or L.CLICK_TO_COMPLETE, style = "done" }
        elseif q.completionText then
            list[#list + 1] = { text = q.completionText, style = "done", check = true }
        elseif q.waypoint then
            list[#list + 1] = { text = q.waypoint, style = "done", check = true }
        else
            list[#list + 1] = { text = QUEST_WATCH_QUEST_READY or L.READY_FOR_TURN_IN, style = "done", check = true }
        end
        return list
    end
    if q.isFailed then
        list[#list + 1] = { text = FAILED or L.FAILED, style = "done", color = { 1, 0.25, 0.25 } }
        return list
    end
    if q.waypoint then
        local fmt = WAYPOINT_OBJECTIVE_FORMAT_OPTIONAL or "%s"
        list[#list + 1] = { text = fmt:format(q.waypoint) }
    end
    for _, o in ipairs(q.objectives) do
        if not o.done or S("showDoneObjectives") then list[#list + 1] = o end
    end
    if q.money then
        local text = GetMoneyString and (GetMoneyString(q.money.have) .. " / " .. GetMoneyString(q.money.need))
            or (q.money.have .. " / " .. q.money.need)
        list[#list + 1] = { text = text }
    end
    return list
end

-- The title text: "[34] Tiger Mastery", the level in its difficulty colour.
function Rows.TitleText(q)
    if not S("showLevel") or not q.level or q.level <= 0 then return q.title end
    local level = "[" .. q.level .. "]"
    if S("levelColors") and q.levelColor then
        level = "|cff" .. hex(q.levelColor) .. level .. "|r"
    end
    return level .. " " .. q.title
end

-- quest or recipe row. Returns height and whether it wants an item button.
function Rows.LayoutQuest(row, q, width, index)
    row.quest, row.recipe = q, nil
    local hasItem = S("showItems") and q.item ~= nil
    local x = S("showPOI") and Rows.POI_W or 0
    local colW = width - x - (hasItem and Rows.ITEM_W or 0)

    if S("showPOI") then
        row.poi:ClearAllPoints()
        row.poi:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 3)
        layoutPOI(row.poi, q, index)
        row.poi:Show()
    else
        row.poi:Hide()
    end

    local titleStyle = Settings.TextStyle("title")
    Media.ApplyText(row.title, titleStyle)
    row.titleColor = titleStyle.color
    local tagW = layoutTag(row.tag, S("showTags") and q.tag or nil, titleStyle)
    row.title:SetText(Rows.TitleText(q))
    local titleW = colW - (tagW > 0 and (tagW + 6) or 0)
    row.title:SetWidth(0)
    local natural = row.title:GetStringWidth()
    row.title:SetWidth(math.max(30, math.min(natural + 1, titleW)))
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
    if tagW > 0 then
        row.tag:ClearAllPoints()
        row.tag:SetPoint("LEFT", row.title, "TOPRIGHT", 6, -titleStyle.size / 2)
    end
    local y = row.title:GetStringHeight()

    local wanted = Rows.QuestLines(q)
    local pool = lines(row, #wanted)
    for i, o in ipairs(wanted) do
        y = y + LINE_GAP
        y = y + layoutLine(row, pool[i], o, x, y, colW, o.style)
    end
    if hasItem then y = math.max(y, ns.Items.SIZE) end
    row:SetSize(width, y)
    return y, hasItem
end

-- A tracked recipe: its name as the title, the reagents as objectives.
function Rows.LayoutRecipe(row, r, width)
    row.quest, row.recipe = nil, r
    row.poi:Hide()
    row.tag:Hide()
    local titleStyle = Settings.TextStyle("title")
    Media.ApplyText(row.title, titleStyle)
    row.titleColor = titleStyle.color
    row.title:SetWidth(width)
    row.title:SetText(r.name)
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    local y = row.title:GetStringHeight()
    local pool = lines(row, #r.reagents)
    for i, o in ipairs(r.reagents) do
        y = y + LINE_GAP
        local line = { text = o.text, cur = o.cur, max = o.max, done = o.done, check = o.done }
        y = y + layoutLine(row, pool[i], line, 0, y, width)
    end
    row:SetSize(width, y)
    return y
end

Rows.NewZoneRow = newZoneRow
Rows.NewQuestRow = newQuestRow
