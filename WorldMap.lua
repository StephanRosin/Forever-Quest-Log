local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

-- The world map (WorldMapFrame, with the quest log beside it): moved freely
-- by its title bar, and optionally framed like the tracker. Everything else
-- stays Blizzard's.
--
-- The map is a UI panel. Its place is set by Blizzard's panel manager, a
-- forbidden delegate frame (FramePositionDelegate, UIParentPanelManager.lua)
-- whenever panels open or close. Nothing here changes that machinery
-- (attributes, UIPanelWindows): that would run the panel manager tainted.
-- Instead, while the map is open, a watcher puts it back where the player
-- dragged it each time Blizzard has placed it. Only C calls on the map
-- (SetPoint, StartMoving, SetAlpha on parts of its border); none of its
-- regions is protected, so this works in combat too. The maximized map is
-- left alone.
local WorldMap = {}
ns.WorldMap = WorldMap

local TITLE_H = 24
local SIDE = 64          -- leave the portrait (left) and the buttons (right) free

local map, overlay, handle

local function maximized()
    return map.IsMaximized and map:IsMaximized() or false
end

-- Placement ---------------------------------------------------------------

-- Where it should be: point, x, y in UIParent units, or nil (Blizzard's).
local function wanted()
    if not S("mapMove") or not S("mapPlaced") or maximized() then return nil end
    return S("mapPoint"), S("mapX"), S("mapY")
end

function WorldMap.Place()
    if not map then return end
    local point, x, y = wanted()
    if not point then return end
    local s = map:GetScale()
    local cur, rel, relPoint, cx, cy = map:GetPoint(1)
    local tx, ty = x / s, y / s
    if cur == point and rel == UIParent and relPoint == point and cx and math.abs(cx - tx) < 0.5
        and math.abs(cy - ty) < 0.5 and map:GetNumPoints() == 1 then
        return
    end
    map:ClearAllPoints()
    map:SetPoint(point, UIParent, point, tx, ty)
end

-- After dragging: anchored at the corner nearest to it, offsets in UIParent
-- units.
local function savePosition()
    local s = map:GetScale()
    local left, right = map:GetLeft() * s, map:GetRight() * s
    local top, bottom = map:GetTop() * s, map:GetBottom() * s
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local h = ((left + right) / 2 < sw / 2) and "LEFT" or "RIGHT"
    local v = ((top + bottom) / 2 < sh / 2) and "BOTTOM" or "TOP"
    local x = (h == "LEFT") and left or (right - sw)
    local y = (v == "TOP") and (top - sh) or bottom
    Settings.SetMany({ mapPlaced = true, mapPoint = v .. h, mapX = math.floor(x + 0.5), mapY = math.floor(y + 0.5) })
end

function WorldMap.ResetPosition()
    Settings.SetMany({ mapPlaced = false })
    -- Blizzard places it again the next time it opens.
end

-- The drag handle: an invisible strip over the title bar, between the
-- portrait and the buttons, above Blizzard's border.
local function createHandle()
    handle = CreateFrame("Frame", nil, map)
    handle:SetFrameStrata("HIGH")
    handle:SetFrameLevel(map.BorderFrame and (map.BorderFrame:GetFrameLevel() + 600) or 600)
    handle:SetPoint("TOPLEFT", map, "TOPLEFT", SIDE, 0)
    handle:SetPoint("TOPRIGHT", map, "TOPRIGHT", -SIDE, 0)
    handle:SetHeight(TITLE_H)
    handle:EnableMouse(true)
    handle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not S("mapMove") or maximized() then return end
        map:SetMovable(true)
        map:SetClampedToScreen(true)
        map:StartMoving()
        WorldMap.moving = true
    end)
    handle:SetScript("OnMouseUp", function()
        if not WorldMap.moving then return end
        map:StopMovingOrSizing()
        WorldMap.moving = nil
        savePosition()
    end)
    handle:SetScript("OnEnter", function(self)
        if not S("mapMove") or maximized() then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.TIP_MAP_DRAG, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Look --------------------------------------------------------------------

-- The look in use: nil for Blizzard's, else a Border look.
function WorldMap.Look()
    local mode = S("mapStyle")
    if mode == "BLIZZARD" then return nil end
    local p = mode == "TRACKER" and "" or "map"
    local function get(key)
        if p == "" then return S(key) end
        return S(p .. key:sub(1, 1):upper() .. key:sub(2))
    end
    return {
        style = get("borderStyle"), size = get("borderSize"), color = get("borderColor"),
        -- The map's content is square: a rounded ring would let its corners
        -- poke out, so the map's frame keeps square corners.
        radius = 0,
        shadow = get("shadowEnabled"), shadowSize = get("shadowSize"), shadowAlpha = get("shadowAlpha") / 100,
    }
end

-- Blizzard's border parts the own look replaces (alpha only: Blizzard sets
-- its border again on minimize / maximize, alpha stays).
local function blizzardParts()
    local b = map.BorderFrame
    if not b then return {} end
    return { b.NineSlice, b.PortraitContainer, b.TopTileStreaks }
end

function WorldMap.ApplyLook()
    if not map then return end
    local look = WorldMap.Look()
    for _, part in pairs(blizzardParts()) do
        if part and part.SetAlpha then part:SetAlpha(look and 0 or 1) end
    end
    if look then
        overlay:Show()
        ns.Border.Draw(overlay, overlay, look)
    else
        overlay:Hide()
    end
end

-- Building ----------------------------------------------------------------

local elapsed = 0
local function watch(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 or WorldMap.moving then return end
    elapsed = 0
    WorldMap.Place()
end

function WorldMap.Build()
    if map or not _G.WorldMapFrame then return end
    map = _G.WorldMapFrame
    -- The border sits on its own frame over the map, as high as Blizzard's.
    overlay = CreateFrame("Frame", nil, map)
    overlay:SetAllPoints(map)
    overlay:SetFrameStrata("HIGH")
    overlay:SetFrameLevel(map.BorderFrame and (map.BorderFrame:GetFrameLevel() + 1) or 1)
    overlay:Hide()
    createHandle()
    -- Runs only while the map is open (a child of it).
    handle:SetScript("OnUpdate", watch)
    map:HookScript("OnShow", function()
        WorldMap.Place()
        WorldMap.ApplyLook()
    end)
    WorldMap.ApplyLook()
end

ns.On("PLAYER_LOGIN", function() WorldMap.Build() end)
ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_WorldMap" then WorldMap.Build() end end)

Settings.OnChange(function(key)
    if not map then return end
    if key == nil or key:find("^map") or key:find("^border") or key:find("^shadow") then
        WorldMap.ApplyLook()
        if map:IsShown() then WorldMap.Place() end
    end
end)
