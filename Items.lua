local ADDON, ns = ...

-- Quest item buttons. Blizzard's tracker uses a plain button that calls
-- UseQuestLogSpecialItem; from addon code that could be blocked, so ours
-- are secure action buttons (type "item"), which use the item in combat
-- too.
--
-- Secure frames cannot be shown, hidden or moved in combat, and a frame a
-- secure frame is anchored to becomes protected itself. So the buttons are
-- children of UIParent, placed at their row's position on the screen (not
-- anchored to it): the tracker stays an ordinary frame that can be dragged,
-- collapsed and scrolled in combat. Placing waits for the end of combat
-- (Tracker.lua keeps the rows still meanwhile while buttons show).
local Items = {}
ns.Items = Items

Items.SIZE = 26
local buttons = {}      -- in use, in order
local pool = {}         -- free
local count = 0

local function itemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function onEnter(self)
    if not self.logIndex then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetQuestLogSpecialItem(self.logIndex)
end

-- A function on the button the secure template calls for an unknown type
-- (here "fqllink", the shift click): links the item in the chat, as
-- Blizzard's button does with the chat link modifier.
local function linkItem(self)
    if self.link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(self.link) end
end

local function update(self, elapsed)
    self.rangeTimer = (self.rangeTimer or 0) - elapsed
    if self.rangeTimer > 0 then return end
    self.rangeTimer = 0.2
    local inRange = self.logIndex and IsQuestLogSpecialItemInRange and IsQuestLogSpecialItemInRange(self.logIndex)
    if inRange == 0 then
        self.icon:SetVertexColor(0.8, 0.1, 0.1)
    else
        self.icon:SetVertexColor(1, 1, 1)
    end
end

local function newButton()
    count = count + 1
    local b = CreateFrame("Button", "ForeverQuestLogItem" .. count, UIParent, "SecureActionButtonTemplate")
    b:SetSize(Items.SIZE, Items.SIZE)
    b:SetFrameStrata("MEDIUM")
    -- Both, so it works with either setting of ActionButtonUseKeyDown.
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    b:SetAttribute("shift-type1", "fqllink")
    b.fqllink = linkItem
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetAllPoints()
    b.edge:SetColorTexture(0.78, 0.59, 0.13, 1)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b.icon)
    hl:SetColorTexture(1, 1, 1, 0.2)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnUpdate", update)
    b:Hide()
    return b
end

local function setItem(b, item)
    b.logIndex, b.link = item.logIndex, item.link
    local id = itemID(item.link)
    b:SetAttribute("item", id and ("item:" .. id) or nil)
    b.icon:SetTexture(item.texture)
    b.count:SetText((item.charges and item.charges > 1) and item.charges or "")
    Items.UpdateCooldown(b)
end

function Items.UpdateCooldown(b)
    if not (b.logIndex and GetQuestLogSpecialItemCooldown) then return end
    local start, duration, enable = GetQuestLogSpecialItemCooldown(b.logIndex)
    if start and duration and duration > 0 and enable ~= 0 then
        b.cooldown:SetCooldown(start, duration)
    else
        b.cooldown:Clear()
    end
end

-- wanted: { { item = <Data item>, x, y, scale }, ... } in screen units of
-- UIParent (x / y: the button's top right). Out of combat only.
function Items.Place(wanted)
    if InCombatLockdown() then return false end
    for i, w in ipairs(wanted) do
        local b = buttons[i]
        if not b then
            b = table.remove(pool) or newButton()
            buttons[i] = b
        end
        setItem(b, w.item)
        b:SetScale(w.scale or 1)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", w.x / (w.scale or 1), w.y / (w.scale or 1))
        b:Show()
    end
    for i = #buttons, #wanted + 1, -1 do
        local b = table.remove(buttons, i)
        b:Hide()
        b.logIndex, b.link = nil, nil
        pool[#pool + 1] = b
    end
    return true
end

-- Alpha follows the tracker (fading, collapsing). Allowed in combat.
function Items.SetAlpha(alpha)
    for _, b in ipairs(buttons) do b:SetAlpha(alpha) end
end

function Items.Count() return #buttons end

function Items.Buttons() return buttons end

ns.On("BAG_UPDATE_COOLDOWN", function()
    for _, b in ipairs(buttons) do Items.UpdateCooldown(b) end
end)
