-- Tests for Forever Quest Log. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
local ROOT = ADDONDIR
local ADDON = "ForeverQuestLog"

local function tocFiles()
    local files = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

-- The quest log the tests start from.
M.log = {
    { header = "Stranglethorn Vale" },
    { id = 185, title = "Tiger Mastery", level = 34,
      objectives = { { text = "Young Stranglethorn Tiger slain: 7/10", have = 7, need = 10 } } },
    { id = 605, title = "Singing Blue Shards", level = 37,
      item = { link = "|cffffffff|Hitem:3912::::::::|h[Soul Gem]|h|r", texture = "ICON_GEM", charges = 1 },
      objectives = { { text = "Singing Crystal Shard: 4/10", type = "item", have = 4, need = 10 } } },
    { id = 189, title = "Bloodscalp Ears", level = 36, complete = true,
      completionText = "Return to Kin'weelay at Grom'gol.",
      objectives = { { text = "Bloodscalp Ear: 15/15", type = "item", have = 15, need = 15, finished = true } } },
    { header = "Duskwood" },
    { id = 56, title = "The Night Watch", level = 33,
      objectives = { { text = "Skeletal Fiend slain: 15/15", have = 15, need = 15, finished = true },
                     { text = "Skeletal Horror slain: 9/15", have = 9, need = 15 } } },
    { id = 228, title = "Mor'Ladim", level = 32, tag = "Elite",
      objectives = { { text = "Mor'Ladim's Skull: 0/1", type = "item", have = 0, need = 1 } } },
    { header = "The Deadmines" },
    { id = 214, title = "Red Silk Bandanas", level = 17,
      objectives = { { text = "Red Silk Bandana: 4/10", type = "item", have = 4, need = 10 } } },
}
M.watches = { 185, 605, 189, 56, 228 }

local ns = {}
for _, f in ipairs(tocFiles()) do
    local chunk, err = loadfile(ROOT .. "/" .. f)
    if not chunk then error(f .. ": " .. tostring(err)) end
    local ok, e = pcall(chunk, ADDON, ns)
    if not ok then error(f .. ": " .. tostring(e)) end
end

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-58s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function section(name) print(name) end

local S, Settings, Tracker, Data, Sort = ns.Settings.Get, ns.Settings, ns.Tracker, ns.Data, ns.Sort

M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()

local frame = M.byName["ForeverQuestLogFrame"]

section("Shipped defaults")
check("quest list in the map: own look", S("logStyle"), "OWN")
check("focus frame shipped locked", S("focusLocked"), true)
check("one list", S("groupByZone"), false)
check("sorted by level", S("sortBy"), "LEVEL")
check("no border", S("borderStyle"), "NONE")
check("gold dialog texture, built in", ns.Media.Path("background", S("bgTexture")),
    "Interface\\DialogFrame\\UI-DialogBox-Gold-Background")
check("only this dungeon's quests", S("instanceOnlyHere"), true)

-- The rest runs on the Forever preset's look, so it does not change with
-- the defaults.
for _, preset in ipairs(Settings.PRESETS) do
    if preset.id == "FOREVER" then
        for k, v in pairs(preset.values) do ns.DB()[k] = v end
    end
end
Settings.Changed(nil)
M.RunTimers()

-- Rows on screen: zone rows have .chevron, quest rows .title.
local function shownRows(field)
    local list = {}
    for _, f in ipairs(M.frames) do
        if f[field] and f._shown and f._parent and f._parent._parent == M.byName["ForeverQuestLogScroll"] then
            list[#list + 1] = f
        end
    end
    return list
end
local function questRows() return shownRows("title") end
local function zoneRows() return shownRows("chevron") end
local function questTitles()
    local t = {}
    for _, row in ipairs(questRows()) do
        if row.quest then t[#t + 1] = row.quest.title elseif row.recipe then t[#t + 1] = row.recipe.name end
    end
    return table.concat(t, ",")
end
local function zoneNames()
    local t = {}
    for _, row in ipairs(zoneRows()) do t[#t + 1] = row.name._text end
    return table.concat(t, ",")
end
local function relayout() Tracker.Refresh(); M.RunTimers() end

section("Blizzard's tracker is left alone")
check("built", frame ~= nil, true)
check("Blizzard's tracker: tiny scale", M.objectiveTracker._scale, ns.Blizzard.SCALE)
check("Blizzard's tracker: alpha 0", M.objectiveTracker._alpha, 0)
check("Blizzard's tracker: still shown (never Hide)", M.objectiveTracker._shown, true)
check("no field written, no method called on it", table.concat(M.violations, ","), "")
check("hidden as wanted", ns.Blizzard.IsHidden(), true)
M.objectiveTracker._scale = 1           -- Edit Mode put it back
relayout()
check("scale reset is noticed", M.objectiveTracker._scale, ns.Blizzard.SCALE)

section("Objective text")
local name, cur, max = Data.SplitCount("Young Tiger slain: 7/10")
check("name: count", name .. "|" .. cur .. "|" .. max, "Young Tiger slain|7|10")
name, cur, max = Data.SplitCount("7/10 Young Tiger slain")
check("count name", name .. "|" .. cur .. "|" .. max, "Young Tiger slain|7|10")
name, cur = Data.SplitCount("Find the cave")
check("plain text stays", name, "Find the cave")
check("plain text: no count", cur, nil)

section("Quest data")
local quests = Data.Quests()
check("all watched quests", #quests, 5)
check("watch order", quests[1].title, "Tiger Mastery")
check("zone from the log header", quests[1].zone, "Stranglethorn Vale")
check("zone of a later header", quests[4].zone, "Duskwood")
check("objective without count in the text", quests[1].objectives[1].text, "Young Stranglethorn Tiger slain")
check("objective count", quests[1].objectives[1].cur .. "/" .. quests[1].objectives[1].max, "7/10")
check("quest item", quests[2].item and quests[2].item.texture, "ICON_GEM")
check("complete", quests[3].isComplete, true)
check("completion text", quests[3].completionText, "Return to Kin'weelay at Grom'gol.")
check("tag", quests[5].tag, "Elite")
check("level colour: green at 32", quests[5].levelColor[2], 0.75)
check("one-of objectives keep their text", quests[5].objectives[1].max, 1)

section("Sorting and grouping")
local e = Sort.Build(quests, { groupByZone = true })
check("zone first", e[1].kind .. ":" .. e[1].name, "zone:Stranglethorn Vale")
check("zone count", e[1].count, 3)
check("then its quests", e[2].quest.title, "Tiger Mastery")
check("second zone", e[5].name, "Duskwood")
e = Sort.Build(quests, { groupByZone = false, sortBy = "LEVEL" })
check("no zones when off", e[1].kind, "quest")
check("lowest level first", e[1].quest.title, "Mor'Ladim")
check("highest last", e[5].quest.title, "Singing Blue Shards")
e = Sort.Build(quests, { groupByZone = true, sortBy = "LEVEL" })
check("by level: the zone with the lowest quest first", e[1].name, "Duskwood")
check("by level inside the zone", e[2].quest.title, "Mor'Ladim")
e = Sort.Build(quests, { groupByZone = true, currentZoneFirst = true, currentZone = "Duskwood" })
check("current zone first", e[1].name, "Duskwood")
e = Sort.Build(quests, { groupByZone = true, collapsedZones = { ["Stranglethorn Vale"] = true } })
check("collapsed zone: header stays", e[1].collapsed, true)
check("collapsed zone: no quests", e[2].kind .. ":" .. (e[2].name or ""), "zone:Duskwood")
e = Sort.Build(quests, { groupByZone = false, onlyZone = "duskwood" })
check("only one zone (any case)", #e, 2)
local unknown = { { id = 1, title = "X", level = 1, watchIndex = 1 } }
check("quest without header: Other", Sort.Build(unknown, { groupByZone = true })[1].name, ns.L.ZONE_OTHER)

section("The list on screen")
check("zones shown", zoneNames(), "Stranglethorn Vale,Duskwood")
check("quests in zone order", questTitles(), "Tiger Mastery,Singing Blue Shards,Bloodscalp Ears,The Night Watch,Mor'Ladim")
local tiger = questRows()[1]
check("title with level", (tiger.title._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), "[34] Tiger Mastery")
check("level in its colour", tiger.title._text:find("|cff", 1, true) == 1, true)
check("map button for the quest", tiger.poi.questID, 185)
check("map button style: in progress", tiger.poi.style, POIButtonUtil.Style.QuestInProgress)
local function lineTexts(row)
    local t = {}
    for _, line in ipairs(row.lines or {}) do
        if line.text._shown then t[#t + 1] = line.text._text .. (line.count._shown and ("=" .. line.count._text) or "") end
    end
    return table.concat(t, "|")
end
check("objective line and count", lineTexts(tiger), "Young Stranglethorn Tiger slain=7/10")
check("a bar under it", tiger.lines[1].barBg._shown, true)
check("the bar 70 % full", tiger.lines[1].bar._w / tiger.lines[1].barBg._w, 0.7)
local ears = questRows()[3]
check("complete: only how to turn it in", lineTexts(ears), "Return to Kin'weelay at Grom'gol.")
check("complete: check mark", ears.lines[1].icon._shown, true)
check("complete: map button style", ears.poi.style, POIButtonUtil.Style.QuestComplete)
local watch = questRows()[4]
check("finished objective dimmed", watch.lines[1].text._textColor[1], S("objectiveDoneColor")[1])
check("finished objective: no bar", watch.lines[1].barBg._shown, false)
local skull = questRows()[5]
check("tag shown", skull.tag._shown, true)
check("one-of objective: no bar", skull.lines[1].barBg._shown, false)
local headerFrame
for _, f in ipairs(M.frames) do if f.countHover then headerFrame = f end end
check("count like the quest log: in the log / maximum", headerFrame.count._text, "6 / 40")
headerFrame.countHover:GetScript("OnEnter")(headerFrame.countHover)
check("tooltip: tracked", GameTooltip._lines[1], "5 of them tracked")

Settings.Set("showDoneObjectives", false)
relayout()
check("finished objectives can be hidden", lineTexts(questRows()[4]), "Skeletal Horror slain=9/15")
Settings.Set("showDoneObjectives", nil)
Settings.Set("showLevel", false)
relayout()
check("level can be hidden", questRows()[1].title._text, "Tiger Mastery")
Settings.Set("showLevel", nil)
relayout()

section("Header buttons")
local header
for _, f in ipairs(M.frames) do if f.zones and f.sort and f.collapse then header = f end end
check("header found", header ~= nil, true)
header.zones:GetScript("OnClick")(header.zones)
M.RunTimers()
check("zones button: one list", #zoneRows(), 0)
check("setting off", S("groupByZone"), false)
header.sort:GetScript("OnClick")(header.sort)
M.RunTimers()
check("sort button: by level", questTitles():sub(1, 9), "Mor'Ladim")
header.sort:GetScript("OnClick")(header.sort)
header.zones:GetScript("OnClick")(header.zones)
M.RunTimers()
check("back to zones", #zoneRows(), 2)
check("back to Blizzard's order", S("sortBy"), "WATCH")
header.collapse:GetScript("OnClick")(header.collapse)
M.RunTimers()
check("collapse: header only", frame._h, 32)
check("collapse: list hidden", M.byName["ForeverQuestLogScroll"]._shown, false)
header.collapse:GetScript("OnClick")(header.collapse)
M.RunTimers()
check("expand again", M.byName["ForeverQuestLogScroll"]._shown, true)
zoneRows()[1]:GetScript("OnClick")(zoneRows()[1])
M.RunTimers()
check("zone collapses", questTitles(), "The Night Watch,Mor'Ladim")
check("remembered per character", ns.CharState().zones["Stranglethorn Vale"], true)
zoneRows()[1]:GetScript("OnClick")(zoneRows()[1])
M.RunTimers()

section("Clicks do what Blizzard's tracker does")
local function lastCall() local c = M.calls[#M.calls]; return c and (c[1] .. ":" .. tostring(c[2])) end
M.calls = {}
tiger = questRows()[1]
tiger:GetScript("OnClick")(tiger, "LeftButton")
check("left click: quest details on the map", lastCall(), "QuestMapFrame_OpenToQuestDetails:185")
M.state.modified.QUESTWATCHTOGGLE = true
tiger:GetScript("OnClick")(tiger, "LeftButton")
check("shift click: stop tracking", lastCall(), "RemoveQuestWatch:185")
M.state.modified.QUESTWATCHTOGGLE = false
M.state.chatOpen = true
M.calls = {}
tiger:GetScript("OnClick")(tiger, "LeftButton")
check("with the chat open: link, nothing else", #M.calls, 0)
M.state.chatOpen = false
tiger:GetScript("OnClick")(tiger, "RightButton")
local menu = M.menus[#M.menus]
local texts = {}
for _, entry in ipairs(menu.entries) do texts[#texts + 1] = entry.text end
check("right click menu", table.concat(texts, ","),
    "Tiger Mastery,Focus,Open quest details,Show on map,Untrack,Abandon")
menu.entries[2].fn()
check("menu: focus", M.superTracked, 185)
M.state.group = true
tiger:GetScript("OnClick")(tiger, "RightButton")
menu = M.menus[#M.menus]
check("in a group: share", menu.entries[6].text, "Share")
check("focused: stop focus", menu.entries[2].text, "Stop focus")
tiger:GetScript("OnEnter")(tiger)
check("hover in a group: party progress", lastCall(), "SetQuestPartyProgress:185")
tiger:GetScript("OnLeave")(tiger)
M.state.group = false
M.superTracked = 0
-- Auto-complete quests complete from the tracker.
M.quest(189).autoComplete = true
relayout()
ears = questRows()[3]
check("auto-complete: click to complete", lineTexts(ears), "Quest complete|Click to complete")
ears:GetScript("OnClick")(ears, "LeftButton")
check("auto-complete click: completes", lastCall(), "ShowQuestComplete:189")
M.quest(189).autoComplete = nil
-- Failed and money.
M.quest(185).failed = true
M.quest(56).money = 1000
relayout()
check("failed", lineTexts(questRows()[1]), "Failed")
check("money still missing", lineTexts(questRows()[4]):find("500c / 1000c", 1, true) ~= nil, true)
M.quest(185).failed = nil
M.quest(56).money = nil
-- Way point for the focused quest.
M.superTracked = 56
M.quest(56).waypoint = "Go to Raven Hill"
relayout()
check("way point line first", lineTexts(questRows()[4]):sub(1, 16), "Go to Raven Hill")
check("focused: map button selected", questRows()[4].poi.selected, true)
M.superTracked = 0
M.quest(56).waypoint = nil
relayout()

section("Quest item buttons")
local scrollFrame = M.byName["ForeverQuestLogScroll"]
scrollFrame._rect = { 1612, 300, 300, 400 }
for i, row in ipairs(questRows()) do row._rect = { 1612, 700 - i * 60, 300, 50 } end
ns.Items.Place({})
relayout()
for i, row in ipairs(questRows()) do row._rect = { 1612, 700 - i * 60, 300, 50 } end
relayout()
local item = ns.Items.Buttons()[1]
check("one item button", ns.Items.Count(), 1)
check("secure", item and item._secure, true)
check("uses the item by id", item and item:GetAttribute("item"), "item:3912")
check("shift click links instead", item and item:GetAttribute("shift-type1"), "fqllink")
check("works with key down and up", item and item._clicks[1] .. "," .. item._clicks[2], "AnyUp,AnyDown")
check("on UIParent, not on the tracker", item and item._parent, UIParent)
check("at its row's right edge", item and item._lastPoint[4], 1912)

section("Combat")
M.state.combat = true
M.watches = { 185, 605, 189, 56, 228, 214 }
M.Fire("QUEST_WATCH_LIST_CHANGED")
M.RunTimers()
check("new quest in combat with item buttons: waits", ns.Tracker.IsLayoutPending(), true)
check("rows unchanged meanwhile", #questRows(), 5)
check("item buttons untouched", ns.Items.Count(), 1)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
M.RunTimers()
check("after combat: laid out", #questRows(), 6)
check("nothing pending", ns.Tracker.IsLayoutPending(), false)
M.watches = { 185, 605, 189, 56, 228 }
relayout()
Settings.Set("combatCollapse", true)
M.Fire("PLAYER_REGEN_DISABLED")
check("collapse in combat", ns.CharState().collapsed, true)
check("item buttons gone before the lockdown", ns.Items.Count(), 0)
M.state.combat = true
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
M.RunTimers()
check("open again after combat", ns.CharState().collapsed, false)
Settings.Set("combatCollapse", nil)

section("Dungeons")
M.state.instance = { name = "The Deadmines", kind = "party" }
M.watches = { 185, 605, 189, 56, 228, 214 }
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()
check("entering collapses", ns.CharState().collapsed, true)
check("chip shown", header.chip._shown, true)
check("chip: all quests by default", header.chip.text._text, ns.L.CHIP_ALL_QUESTS)
-- Narrow: the chip would cover the count, so it gets a line of its own.
local chipPoint = header.chip._points
check("narrow: chip under the header", chipPoint.TOPLEFT and chipPoint.TOPLEFT[2], "BOTTOMLEFT")
check("narrow: not in the header", chipPoint.LEFT, nil)
check("narrow: frame taller by the chip's line", frame:GetHeight(), 32 + 22)
Settings.Set("width", 400)
M.RunTimers()
chipPoint = header.chip._points
check("wide: chip after the count", chipPoint.LEFT and chipPoint.LEFT[1], header)
local countRight = 10 + header.title:GetStringWidth() + 6 + header.count:GetStringWidth()
check("wide: right of the count", chipPoint.LEFT and chipPoint.LEFT[3], countRight + 8)
check("wide: clear of the buttons", countRight + 8 + header.chip:GetWidth() <= 400 - 5 - 5 * 22 - 4, true)
check("wide: frame only the header", frame:GetHeight(), 32)
Settings.Set("width", nil)
M.RunTimers()
header.chip:GetScript("OnClick")(header.chip)
M.RunTimers()
check("chip: only this dungeon", questTitles(), "Red Silk Bandanas")
check("chip opens the list", ns.CharState().collapsed, false)
M.Fire("PLAYER_ENTERING_WORLD")      -- a /reload inside
M.RunTimers()
check("reload inside: stays open", ns.CharState().collapsed, false)
M.state.instance = nil
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()
check("leaving: as before", ns.CharState().collapsed, false)
check("leaving: all quests", #questRows(), 6)
check("chip gone", header.chip._shown, false)
Settings.Set("instanceOnlyHere", true)
ns.CharState().collapsed = true
M.state.instance = { name = "The Deadmines", kind = "party" }
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()
header.collapse:GetScript("OnClick")(header.collapse)
M.RunTimers()
check("set to only here: from the start", questTitles(), "Red Silk Bandanas")
M.state.instance = nil
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()
check("leaving restores collapsed", ns.CharState().collapsed, true)
ns.CharState().collapsed = false
Settings.Set("instanceOnlyHere", nil)
Settings.Set("instanceCollapse", false)
M.state.instance = { name = "Stratholme", kind = "raid" }
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()
check("collapse off: stays open", ns.CharState().collapsed, false)
M.state.instance = nil
M.Fire("PLAYER_ENTERING_WORLD")
Settings.Set("instanceCollapse", nil)
M.watches = { 185, 605, 189, 56, 228 }
relayout()

section("Recipes")
M.recipes = { { id = 2329, name = "Elixir of the Mongoose", reagents = {
    { itemID = 2452, have = 2, need = 2 }, { itemID = 3820, have = 1, need = 2 } } } }
M.itemNames = { [2452] = "Swiftthistle" }
M.Fire("TRACKED_RECIPE_UPDATE")
M.RunTimers()
check("section header", zoneNames():find("Professions", 1, true) ~= nil, true)
local recipeRow
for _, row in ipairs(questRows()) do if row.recipe then recipeRow = row end end
check("recipe row", recipeRow and recipeRow.recipe.name, "Elixir of the Mongoose")
check("reagents with counts", lineTexts(recipeRow), "Swiftthistle=2/2|Loading...=1/2")
check("unknown item asked for", lastCall(), "RequestLoadItemDataByID:3820")
recipeRow:GetScript("OnClick")(recipeRow, "LeftButton")
check("click opens the recipe", lastCall(), "OpenRecipe:2329")
M.state.modified.RECIPEWATCHTOGGLE = true
recipeRow:GetScript("OnClick")(recipeRow, "LeftButton")
check("shift click untracks", lastCall(), "SetRecipeTracked:2329")
M.state.modified.RECIPEWATCHTOGGLE = false
Settings.Set("showRecipes", false)
relayout()
check("recipes can be switched off", zoneNames():find("Professions", 1, true), nil)
Settings.Set("showRecipes", nil)
M.recipes = {}
relayout()

section("Moving and resizing")
check("locked by default: no outline", frame and S("locked"), true)
Settings.Set("locked", false)
M.RunTimers()
check("unlocked: header drags", (function()
    header:GetScript("OnMouseDown")(header, "LeftButton")
    return frame._moving
end)(), true)
frame._rect = { 1000, 400, 300, 500 }
frame._scale = 1
header:GetScript("OnMouseUp")(header, "LeftButton")
check("dropped on the right half: TOPRIGHT", S("point"), "TOPRIGHT")
check("x from the right edge", S("x"), 1300 - 1920)
check("y from the top", S("y"), 900 - 1080)
frame._rect = { 100, 400, 300, 500 }
header:GetScript("OnMouseDown")(header, "LeftButton")
header:GetScript("OnMouseUp")(header, "LeftButton")
check("left half: TOPLEFT", S("point"), "TOPLEFT")
check("x from the left edge", S("x"), 100)
Settings.Set("locked", true)
M.RunTimers()
frame._moving = false
header:GetScript("OnMouseDown")(header, "LeftButton")
check("locked: no drag", frame._moving, false)
M.state.ctrl = true
header:GetScript("OnMouseDown")(header, "LeftButton")
check("locked, Ctrl: drags", frame._moving, true)
header:GetScript("OnMouseUp")(header, "LeftButton")
M.state.ctrl = false
Settings.Set("locked", false)
M.RunTimers()
local grips = {}
for _, f in ipairs(M.frames) do
    if f.icon and f.icon._texture and f.icon._texture:find("IconArrowCorner") and f._parent == frame then
        grips[f.corner] = f
    end
end
local function gripCount() local n = 0 for _ in pairs(grips) do n = n + 1 end return n end
check("four corner grips", gripCount(), 4)
check("grips shown unlocked", grips.TOPLEFT._shown and grips.TOPRIGHT._shown and grips.BOTTOMLEFT._shown and grips.BOTTOMRIGHT._shown, true)
check("old single grip is gone", (function()
    for _, f in ipairs(M.frames) do
        if f.icon and f.icon._texture and f.icon._texture:find("IconResize") and f._parent == frame then return true end
    end
    return false
end)(), false)
check("top right arrow is not mirrored", grips.TOPRIGHT.icon._texCoord[1] < grips.TOPRIGHT.icon._texCoord[2]
    and grips.TOPRIGHT.icon._texCoord[3] < grips.TOPRIGHT.icon._texCoord[4], true)
check("bottom left arrow is mirrored both ways", grips.BOTTOMLEFT.icon._texCoord[1] > grips.BOTTOMLEFT.icon._texCoord[2]
    and grips.BOTTOMLEFT.icon._texCoord[3] > grips.BOTTOMLEFT.icon._texCoord[4], true)
grips.TOPLEFT:GetScript("OnEnter")(grips.TOPLEFT)
local hov = grips.TOPLEFT.icon._vertex
grips.TOPLEFT:GetScript("OnLeave")(grips.TOPLEFT)
check("brighter on hover", hov[1] > grips.TOPLEFT.icon._vertex[1], true)

-- Drags a corner by (dx, dy) screen pixels on a frame at rect (UIParent scale 1).
local function dragCorner(corner, dx, dy, rect)
    Settings.SetMany({ point = "TOPLEFT", x = rect[1], y = rect[2] + rect[4] - 1080, width = rect[3], height = rect[4], fitContent = false })
    frame._rect = { rect[1], rect[2], rect[3], rect[4] }
    frame._scale, frame._h = 1, rect[4]
    M.state.cursorX, M.state.cursorY = 1000, 600
    local g = grips[corner]
    g:GetScript("OnMouseDown")(g)
    M.state.cursorX, M.state.cursorY = 1000 + dx, 600 + dy
    g:GetScript("OnUpdate")(g, 0.1)
    g:GetScript("OnMouseUp")(g)
end
-- The frame's rectangle from the saved placement: { left, bottom, right, top }.
local function placed()
    local w, h = S("width"), S("height")
    local sw, sh = 1920, 1080
    local left = S("point"):find("LEFT") and S("x") or (sw + S("x") - w)
    local top, bottom
    if S("point"):find("TOP") then top = sh + S("y"); bottom = top - h
    else bottom = S("y") + sh; top = bottom + h end
    return left, bottom, left + w, top
end
local rect = { 600, 300, 300, 400 }   -- left 600, bottom 300, right 900, top 700
dragCorner("BOTTOMRIGHT", 50, -30, rect)
local l, b, r, t = placed()
check("bottom right: size", S("width") .. "x" .. S("height"), "350x430")
check("bottom right: top left stays", l .. "," .. t, "600,700")
dragCorner("TOPLEFT", -40, 25, rect)
l, b, r, t = placed()
check("top left: size", S("width") .. "x" .. S("height"), "340x425")
check("top left: bottom right stays", r .. "," .. b, "900,300")
check("top left: anchor follows the fixed side", S("point"), "TOPRIGHT")
dragCorner("TOPRIGHT", 20, 10, rect)
l, b, r, t = placed()
check("top right: size", S("width") .. "x" .. S("height"), "320x410")
check("top right: bottom left stays", l .. "," .. b, "600,300")
dragCorner("BOTTOMLEFT", -15, -45, rect)
l, b, r, t = placed()
check("bottom left: size", S("width") .. "x" .. S("height"), "315x445")
check("bottom left: top right stays", r .. "," .. t, "900,700")
dragCorner("BOTTOMRIGHT", -5000, 5000, rect)
check("clamped to the minimum", S("width") .. "x" .. S("height"), Settings.RANGES.width[1] .. "x" .. Settings.RANGES.height[1])
l, b, r, t = placed()
check("clamped: fixed corner still stays", l .. "," .. t, "600,700")
dragCorner("TOPLEFT", -5000, 5000, rect)
check("clamped to the maximum", S("width") .. "x" .. S("height"), Settings.RANGES.width[2] .. "x" .. Settings.RANGES.height[2])
l, b, r, t = placed()
check("clamped: fixed corner stays (max)", r .. "," .. b, "900,300")
-- Grips keep clear of the header buttons (rects relative to the frame's top right corner, y up).
local gp = grips.TOPRIGHT._lastPoint
local gw, gh = grips.TOPRIGHT._w, grips.TOPRIGHT._h
check("top right grip hangs off the corner by its bottom left", gp[1] .. gp[3], "BOTTOMLEFTTOPRIGHT")
local g1, g2, g3, g4 = gp[4], gp[5], gp[4] + gw, gp[5] + gh          -- left, bottom, right, top
local cb = header.collapse
local bw, bh = cb._w, cb._h
local b3 = cb._lastPoint[4]                                           -- RIGHT, -5
local b1 = b3 - bw
local b4 = -((header._h - bh) / 2)
local b2 = b4 - bh
check("top right grip does not touch the collapse button",
    g1 < b3 and g3 > b1 and g2 < b4 and g4 > b2, false)
local tl = grips.TOPLEFT._lastPoint
check("top left grip hangs off the corner too", tl[1] .. tl[3], "BOTTOMRIGHTTOPLEFT")
check("the readout sits clear of the bottom grips", (function()
    for _, f in ipairs(M.frames) do
        if f._parent == frame and f.text and f.text._text and f.text._text:find(" x ", 1, true) then
            return math.abs(f._lastPoint[5]) >= grips.BOTTOMLEFT._h
        end
    end
end)(), true)

-- Other anchors: grow UP, scale, a centred anchor, the place() round trip.
local function rectOf(w, h, sc)
    local sw, sh = 1920, 1080
    local pt, x, y = S("point"), S("x"), S("y")
    local left = pt:find("LEFT") and x or (pt:find("RIGHT") and (sw + x - w) or (sw / 2 + x - w / 2))
    if pt:find("TOP") then return left, sh + y - h, left + w, sh + y end
    return left, y, left + w, y + h
end
local function drag(corner, dx, dy, setup, rc, sc)
    Settings.SetMany(setup)
    frame._rect = { rc[1], rc[2], rc[3] / sc, rc[4] / sc }   -- frame units * scale = screen units
    frame._rect = { rc[1] / sc, rc[2] / sc, rc[3] / sc, rc[4] / sc }
    frame._scale, frame._h = sc, rc[4] / sc
    M.state.cursorX, M.state.cursorY = 1000, 600
    grips[corner]:GetScript("OnMouseDown")(grips[corner], "LeftButton")
    M.state.cursorX, M.state.cursorY = 1000 + dx, 600 + dy
    grips[corner]:GetScript("OnUpdate")(grips[corner], 0.1)
    grips[corner]:GetScript("OnMouseUp")(grips[corner], "LeftButton")
end
Settings.SetMany({ grow = "UP" })
drag("TOPRIGHT", 30, 40, { point = "BOTTOMLEFT", x = 600, y = 300, width = 300, height = 400, fitContent = false }, { 600, 300, 300, 400 }, 1)
l, b, r, t = rectOf(S("width"), S("height"))
check("grow up, top right: size", S("width") .. "x" .. S("height"), "330x440")
check("grow up: anchored at the bottom", S("point"), "BOTTOMLEFT")
check("grow up: bottom left stays", l .. "," .. b, "600,300")
drag("TOPLEFT", -30, 40, { point = "BOTTOMLEFT", x = 600, y = 300, width = 300, height = 400, fitContent = false }, { 600, 300, 300, 400 }, 1)
l, b, r, t = rectOf(S("width"), S("height"))
check("grow up, top left: bottom right stays", r .. "," .. b, "900,300")
Settings.SetMany({ grow = "DOWN" })
-- scale 2: the frame is 150 x 200 units; 40 px right is 20 units
drag("BOTTOMRIGHT", 40, -60, { scale = 200, point = "TOPLEFT", x = 600, y = 700 - 1080, width = 200, height = 200, fitContent = false }, { 600, 300, 400, 400 }, 2)
check("scale 2: size in frame units", S("width") .. "x" .. S("height"), "220x230")
l, b, r, t = rectOf(S("width") * 2, S("height") * 2)
check("scale 2: top left stays on screen", l .. "," .. t, "600,700")
check("place() anchors to the saved values", (function()
    local p = frame._lastPoint
    return p[1] == S("point") and p[4] == S("x") / 2 and p[5] == S("y") / 2
end)(), true)
Settings.SetMany({ scale = 100 })
-- starting from a centred anchor (the X / Y sliders write TOP)
drag("BOTTOMRIGHT", 40, -20, { point = "TOP", x = 0, y = 700 - 1080, width = 300, height = 400, fitContent = false }, { 810, 300, 300, 400 }, 1)
l, b, r, t = rectOf(S("width"), S("height"))
check("centred start: becomes a corner anchor", S("point"), "TOPLEFT")
check("centred start: top left stays", l .. "," .. t, "810,700")
-- round trip: the saved values put the frame where the drag left it
Tracker = ns.Tracker
local rl, rb, rr, rt = rectOf(S("width"), S("height"))
ns.Tracker.Layout()
M.RunTimers()
local lp = frame._lastPoint
check("round trip: place() uses the saved point", lp[1], S("point"))
check("round trip: place() uses the saved offsets", lp[4] .. "," .. lp[5], S("x") .. "," .. S("y"))
check("round trip: fixed corner unchanged", rl .. "," .. rt, "810,700")
-- a plain click and the right button change nothing
Settings.SetMany({ point = "TOPLEFT", x = 600, y = -380, width = 300, height = 400, fitContent = true })
frame._rect, frame._h, frame._scale = { 600, 300, 300, 400 }, 400, 1
local g = grips.BOTTOMRIGHT
g:GetScript("OnMouseDown")(g, "LeftButton")
g:GetScript("OnMouseUp")(g, "LeftButton")
check("click without a drag: nothing changes", S("width") .. S("height") .. S("point") .. tostring(S("fitContent")), "300400TOPLEFTtrue")
M.state.cursorX, M.state.cursorY = 1000, 600
g:GetScript("OnMouseDown")(g, "RightButton")
M.state.cursorX = 1100
if g:GetScript("OnUpdate") then g:GetScript("OnUpdate")(g, 0.1) end
g:GetScript("OnMouseUp")(g, "RightButton")
check("right button: no resize", S("width"), 300)
-- a width-only drag from a content height below the minimum: no jump, fitContent stays
frame._h = 60
M.state.cursorX = 1000
g:GetScript("OnMouseDown")(g, "LeftButton")
M.state.cursorX = 1030
g:GetScript("OnUpdate")(g, 0.1)
g:GetScript("OnMouseUp")(g, "LeftButton")
check("short content: width-only drag keeps fitContent", S("fitContent"), true)
check("short content: width grows", S("width"), 330)

-- fitContent: a vertical drag switches it off, a width-only drag does not.
Settings.SetMany({ fitContent = true })
frame._rect, frame._h = { 600, 300, 300, 400 }, 400
M.state.cursorX, M.state.cursorY = 1000, 600
grips.BOTTOMRIGHT:GetScript("OnMouseDown")(grips.BOTTOMRIGHT)
M.state.cursorX = 1040
grips.BOTTOMRIGHT:GetScript("OnUpdate")(grips.BOTTOMRIGHT, 0.1)
grips.BOTTOMRIGHT:GetScript("OnMouseUp")(grips.BOTTOMRIGHT)
check("width-only drag keeps fitContent", S("fitContent"), true)
M.state.cursorY = 600
grips.BOTTOMRIGHT:GetScript("OnMouseDown")(grips.BOTTOMRIGHT)
M.state.cursorY = 500
grips.BOTTOMRIGHT:GetScript("OnUpdate")(grips.BOTTOMRIGHT, 0.1)
grips.BOTTOMRIGHT:GetScript("OnMouseUp")(grips.BOTTOMRIGHT)
check("vertical drag switches fitContent off", S("fitContent"), false)
local readoutText
for _, f in ipairs(M.frames) do
    if f._parent == frame and f.text and f.text._text and f.text._text:find(" x ", 1, true) then readoutText = f.text._text end
end
check("readout shows the size", readoutText and readoutText:find(S("width") .. " x " .. math.floor(frame._h + 0.5), 1, true) ~= nil, true)
Settings.Set("fitContent", nil)
Settings.SetMany({ point = "TOPRIGHT", x = -8, y = -330, width = 300, height = 500 })
Settings.Set("locked", true)
M.RunTimers()
check("grips hidden locked", grips.TOPLEFT._shown or grips.TOPRIGHT._shown or grips.BOTTOMLEFT._shown or grips.BOTTOMRIGHT._shown, false)
ns.Tracker.SnapBelowMinimap()
check("below the minimap", S("y"), 767 - 1080 - 16)
check("right edges in line", S("x"), 1912 - 1920)
Settings.SetMany({ point = "TOPRIGHT", x = -8, y = -330 })

section("Scrollbar only when there is something to scroll")
check("everything fits: no bar", frame.thumb._shown, false)
Settings.Set("height", 120)
relayout()
check("taller than the frame: bar", frame.thumb._shown, true)
Settings.Set("height", nil)
relayout()
check("fits again: bar gone", frame.thumb._shown, false)

section("Exact position: X from the centre, Y from the top")
ns.Window.Open()
ns.Window.ShowPage("layout")
local function sliderRow(label)
    for _, f in ipairs(M.frames) do
        if f.slider and f.label and f.label._text == label and f:IsVisible() then return f end
    end
end
frame._rect = { 1600, 600, 300, 400 }     -- centre x 1750, top 1000
frame._scale = 1
local xRow, yRow = sliderRow("Horizontal (from the centre)"), sliderRow("Vertical (from the top)")
check("X slider", xRow ~= nil, true)
check("Y slider", yRow ~= nil, true)
xRow:Refresh(); yRow:Refresh()
check("X reads the centre from the screen's centre", xRow.slider._value, 1750 - 960)
check("Y reads the top from the screen's top", yRow.slider._value, 1000 - 1080)
xRow.slider:GetScript("OnValueChanged")(xRow.slider, 0, true)
check("X set: centred anchor", S("point"), "TOP")
check("X set: centre offset", S("x"), 0)
check("X set: Y kept", S("y"), -80)
yRow.slider:GetScript("OnValueChanged")(yRow.slider, -200, true)
check("Y set", S("y"), -200)
Settings.Set("grow", "UP")
frame._rect = { 800, 300, 300, 400 }
yRow.slider:GetScript("OnValueChanged")(yRow.slider, -500, true)
check("growing up: the bottom edge, still from the top", S("point") .. ":" .. S("y"), "BOTTOM:" .. (1080 - 500))
Settings.Set("grow", nil)
ns.Window.ShowPage("focus")
check("focus frame: X / Y", sliderRow("Horizontal (from the centre)") ~= nil, true)
ns.Window.ShowPage("map")
local mapX = sliderRow("Horizontal (from the centre)")
check("world map: X / Y", mapX ~= nil, true)
M.worldMap._rect = { 100, 200, 1000, 700 }
mapX.slider:GetScript("OnValueChanged")(mapX.slider, -200, true)
check("world map: placed by the slider", S("mapPlaced") and S("mapPoint"), "TOP")
check("world map: x", S("mapX"), -200)
ns.WorldMap.ResetPosition()
ns.Window.Toggle()
Settings.SetMany({ point = "TOPRIGHT", x = -8, y = -330 })

section("Look")
relayout()
local ring = ns.Border.Pieces(frame)
check("gold ring drawn", ring[1] and ring[1]._shown, true)
check("gold shading", ring[1] and ring[1]._gradient ~= nil, true)
Settings.Set("borderStyle", "NONE")
relayout()
check("no border", ring[1]._shown, false)
Settings.Set("borderStyle", "GOLD")
Settings.Set("bgMode", "TEXTURE")
relayout()
check("texture background", frame.bg._texture, "Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
Settings.Set("bgMode", "SOLID")
Settings.Set("titleSize", 18)
relayout()
check("title size", questRows()[1].title._font[2], 18)
check("map button centred on the title line", questRows()[1].poi._lastPoint[5], -9)
check("map button room: rows start inside", questRows()[1]._lastPoint[4], S("padding"))
Settings.Set("titleFont", "Morpheus")
relayout()
check("title font", questRows()[1].title._font[1], "Fonts\\MORPHEUS.TTF")
Settings.Set("titleFlag", "OUTLINE")
relayout()
check("title outline", questRows()[1].title._font[3], "OUTLINE")
Settings.Set("titleSize", nil); Settings.Set("titleFont", nil); Settings.Set("titleFlag", nil)
Settings.Set("objectiveColor", { 1, 0, 0 })
relayout()
check("objective colour", questRows()[1].lines[1].text._textColor[2], 0)
Settings.Set("objectiveColor", nil)
relayout()

section("Presets and profiles")
check("presets listed", (function()
    for _, n in ipairs(ns.ProfileList()) do if n == "@MINIMAL" then return true end end
    return false
end)(), true)
ns.SwitchProfile("@MINIMAL")
check("preset applied", S("borderStyle"), "NONE")
check("own position kept", S("x"), -8)
ns.SwitchProfile("Default")
check("back", S("borderStyle"), "GOLD")

section("Export and import")
Settings.Set("titleSize", 17)
Settings.Set("barColor", { 0.1, 0.2, 0.3 })
local text = ns.Share.Export()
check("prefix", text:sub(1, 5), "FQL1:")
Settings.ResetProfile()
check("reset", S("titleSize"), Settings.DEFAULTS.titleSize)
check("import", ns.Share.Import(text), true)
check("number back", S("titleSize"), 17)
check("colour back", S("barColor")[3], 0.3)
check("garbage refused", ns.Share.Import("hello"), nil)
check("code is never run", ns.Share.Import("FQL1:s5:os.ex"), nil)
Settings.ResetProfile()

section("Options window")
ns.Window.Open()
check("window shown", ns.Window.IsShown(), true)
local function rowFor(label, field)
    for _, f in ipairs(M.frames) do
        if f[field] and f.label and f.label._text and f.label._text:find(label, 1, true) and f:IsVisible() then
            return f
        end
    end
end
ns.Window.ShowPage("layout")
local width = rowFor("Width", "slider")
check("width slider", width ~= nil, true)
width.slider:GetScript("OnValueChanged")(width.slider, 340, true)
check("slider sets the width", S("width"), 340)
Settings.Set("width", nil)
for _, page in ipairs(ns.Window.PAGES) do
    local ok, err = pcall(ns.Window.ShowPage, page.id)
    check("page " .. page.id .. " builds", ok, true)
    if not ok then print(err) end
end
Settings.Set("bgMode", "SOLID")
ns.Window.ShowPage("appearance")
check("solid background: no texture choice", rowFor("Texture", "button"), nil)
check("solid background: colour", rowFor("Colour", "swatch") ~= nil, true)
Settings.Set("bgMode", "TEXTURE")
check("texture background: texture choice", rowFor("Texture", "button") ~= nil, true)
check("texture background: no colour", rowFor("Colour", "swatch"), nil)
Settings.Set("bgMode", nil)
check("flat border colour only for flat", rowFor("Colour (flat)", "swatch"), nil)
ns.Window.Toggle()
check("closed", ns.Window.IsShown(), false)
-- The options window keeps its place (and page) when the language changes.
do
local Locale = ns.Locale
ns.Window.Open("layout")
local of = M.byName.ForeverQuestLogOptions
of._rect = { 300, 200, of:GetWidth(), of:GetHeight() }
local bar = of.titleBar
bar:GetScript("OnDragStart")(bar)
bar:GetScript("OnDragStop")(bar)
local saved = ns.AccountDB().optionsPosition
check("options position stored on drag", saved ~= nil and saved.x .. "/" .. saved.y,
    (300 + of:GetWidth() / 2 - 960) .. "/" .. (200 + of:GetHeight() - 1080))
of._rect = { 500, 100, of:GetWidth(), of:GetHeight() }
Locale.Set("deDE")
local nf = M.byName.ForeverQuestLogOptions
check("a new window for the language", nf ~= of, true)
check("still open", ns.Window.IsShown(), true)
check("same page", M.byName.ForeverQuestLogPagelayout:IsShown(), true)
check("where the old one was", nf._points.TOP and (nf._points.TOP[3] .. "/" .. nf._points.TOP[4]),
    (500 + of:GetWidth() / 2 - 960) .. "/" .. (100 + of:GetHeight() - 1080))
Locale.Set("AUTO")
ns.AccountDB().optionsPosition = nil
ns.Window.Toggle()
end
check("interface options page", M.registered[1], "Forever Quest Log")

section("Minimap button and slash command")
local mb = M.byName["ForeverQuestLogMinimapButton"]
check("minimap button", mb ~= nil, true)
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click unlocks", S("locked"), false)
mb:GetScript("OnClick")(mb, "RightButton")
M.chat = {}
SlashCmdList["FOREVERQUESTLOG"]("status")
check("status prints", #M.chat >= 3, true)
check("status names the build", M.chat[1]:find("1.60.1", 1, true) ~= nil, true)
check("status: Blizzard's tracker hidden", M.chat[2]:find("hidden", 1, true) ~= nil, true)
SlashCmdList["FOREVERQUESTLOG"]("unlock")
check("/fql unlock", S("locked"), false)
SlashCmdList["FOREVERQUESTLOG"]("lock")
check("/fql lock", S("locked"), true)

section("World map")
local wmf = M.worldMap
Settings.Set("mapPlaced", false)
check("built on the map", ns.WorldMap ~= nil and wmf._scripts.OnShow ~= nil, true)
check("Blizzard's look by default: border untouched", wmf.BorderFrame.NineSlice._alpha, 1)
M.PanelManagerPlaces()
wmf._shown = true
wmf._scripts.OnShow(wmf)
check("not dragged yet: Blizzard's place", wmf._lastPoint[4], 16)
local handle
for _, f in ipairs(M.frames) do if f._parent == WorldMapFrame and f._scripts.OnMouseDown then handle = f end end
check("drag handle on the title bar", handle ~= nil, true)
handle._scripts.OnMouseDown(handle, "LeftButton")
check("dragging moves the map", wmf._moving, true)
wmf._rect = { 1200, 200, 1000, 700 }
handle._scripts.OnMouseUp(handle, "LeftButton")
check("dropped: right half, top half", S("mapPoint"), "TOPRIGHT")
check("x from the right edge", S("mapX"), 2200 - 1920)
check("y from the top", S("mapY"), 900 - 1080)
M.PanelManagerPlaces()
handle._scripts.OnUpdate(handle, 0.1)
check("Blizzard places it: put back", wmf._lastPoint[1] .. "," .. wmf._lastPoint[4], "TOPRIGHT,280")
local before = #M.calls
wmf.isMaximized = true
M.PanelManagerPlaces()
handle._scripts.OnUpdate(handle, 0.1)
check("maximized: left alone", wmf._lastPoint[4], 16)
wmf.isMaximized = false
Settings.Set("mapStyle", "OWN")
check("own look: Blizzard's border faded", wmf.BorderFrame.NineSlice._alpha, 0)
check("own look: portrait faded", wmf.BorderFrame.PortraitContainer._alpha, 0)
check("own look: gold", ns.WorldMap.Look().style, "GOLD")
check("square corners on the map", ns.WorldMap.Look().radius, 0)
Settings.Set("mapStyle", "TRACKER")
check("like the tracker", ns.WorldMap.Look().style, S("borderStyle"))
Settings.Set("mapStyle", "BLIZZARD")
check("Blizzard's again: border back", wmf.BorderFrame.NineSlice._alpha, 1)
ns.WorldMap.ResetPosition()
M.PanelManagerPlaces()
handle._scripts.OnUpdate(handle, 0.1)
check("reset: Blizzard's place stays", wmf._lastPoint[4], 16)
Settings.Set("mapMove", false)
handle._scripts.OnMouseDown(handle, "LeftButton")
wmf._moving = false
handle._scripts.OnMouseDown(handle, "LeftButton")
check("moving off: no drag", wmf._moving, false)
Settings.Set("mapMove", nil)
wmf._shown = false
ns.Window.Open()
local okMap = pcall(ns.Window.ShowPage, "map")
check("map options page", okMap, true)
ns.Window.Toggle()

section("Quest log in the world map")
-- Blizzard's update: acquire, set the text, measure; then the addon's hook
-- on QuestLogQuests_Update runs.
local function blizzardUpdate(text)
    QuestScrollFrame.titleFramePool:ReleaseAll()
    local row = M.QuestLogAddQuest(text)
    QuestLogQuests_Update()
    return row
end
Settings.Set("logStyle", "BLIZZARD")
local row1 = blizzardUpdate("[21] The Greenwarden")
check("Blizzard's style: font untouched", row1.Text._font[2], 12)
check("Blizzard's background shown", QuestScrollFrame.Background._alpha, 1)
Settings.Set("logStyle", "OWN")
Settings.Set("logTitleSize", 18)
check("own style: applied to the rows on screen", row1.Text._font[2], 18)
local row2 = blizzardUpdate("[22] Alchemical Hazards")
check("own style: title size", row2.Text._font[2], 18)
check("next update measures with the new font", row2.measured, 18)
check("own style: Blizzard's parchment faded", QuestScrollFrame.Background._alpha, 0)
check("objectives styled after the update", (function()
    QuestScrollFrame.objectiveFramePool:ReleaseAll()
    local f = QuestScrollFrame.objectiveFramePool:Acquire()
    QuestLogQuests_Update()
    return f.Text._font[1]
end)(), "Fonts\\ARIALN.TTF")
Settings.Set("titleSize", 16)
Settings.Set("logStyle", "TRACKER")
local row3 = blizzardUpdate("[22] Spoils of War")
check("like the tracker: title size", row3.Text._font[2], S("titleSize"))
Settings.Set("logStyle", "BLIZZARD")
local row4 = blizzardUpdate("[24] Digging Through the Ooze")
check("back to Blizzard's: font object again", row4.Text._fontObject, M.fontObjects.GameFontNormalLeft)
check("back to Blizzard's: size", row4.Text._font[2], 12)
check("back to Blizzard's: the same row too (font object unchanged)", row2.Text._font[2], 12)
check("back to Blizzard's: font file", row2.Text._font[1], "Fonts\\FRIZQT__.TTF")
check("Blizzard's background back", QuestScrollFrame.Background._alpha, 1)
check("the list's pools are never hooked", table.concat(M.violations, ","):find("secure pool"), nil)
Settings.Set("logTitleSize", nil)
Settings.Set("titleSize", nil)
ns.Window.Open()
check("quest log options on the world map page", pcall(ns.Window.ShowPage, "map"), true)
check("no own quest log page", (function()
    for _, p in ipairs(ns.Window.PAGES) do if p.id == "questlog" then return true end end
    return false
end)(), false)
ns.Window.Toggle()

section("Selected quest tracker")
local focus = M.byName["ForeverQuestLogFocus"]
check("built", focus ~= nil, true)
M.superTracked = 0
ns.Focus.Layout()
check("nothing focused: gone", focus._shown, false)
Settings.Set("focusLocked", false)
ns.Focus.Layout()
check("nothing focused, unlocked: gone too", focus._shown, false)
Settings.Set("focusLocked", true)
Settings.Set("focusFallback", "FIRST")
ns.Focus.Layout()
check("fallback: first tracked quest", focus._shown and ns.Focus.Quest().title, "Tiger Mastery")
Settings.Set("focusFallback", nil)
M.superTracked = 56
M.Fire("SUPER_TRACKING_CHANGED")
M.RunTimers()
check("focused quest shown", focus._shown, true)
local frow
for _, f in ipairs(M.frames) do if f._parent == focus and f.title then frow = f end end
check("its title", (frow.title._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), "[33] The Night Watch")
check("its progress", frow.lines[2].count._text, "9/15")
check("own title size", frow.title._font[2], S("focusTitleSize"))
Settings.Set("focusTitleSize", 22)
M.RunTimers()
check("title size setting", frow.title._font[2], 22)
check("tracker's titles keep theirs", questRows()[1].title._font[2] ~= 22, true)
Settings.Set("focusTitleSize", nil)
Settings.Set("focusAlpha", 60)
M.RunTimers()
check("opacity", focus._alpha, 0.6)
Settings.Set("focusAlpha", nil)
Settings.Set("focusShowBars", false)
M.RunTimers()
check("bars off for the frame only", frow.lines[2].barBg._shown, false)
Settings.Set("focusShowBars", nil)
M.RunTimers()
-- Dragging (unlocked) moves it and does not open the quest.
Settings.Set("focusLocked", false)
M.RunTimers()
M.calls = {}
frow:GetScript("OnMouseDown")(frow, "LeftButton")
check("drag on the quest moves the frame", focus._moving, true)
focus._rect = { 100, 600, 280, 80 }
focus._scale = 1
frow:GetScript("OnMouseUp")(frow, "LeftButton")
frow:GetScript("OnClick")(frow, "LeftButton")
check("the drag's click does nothing", #M.calls, 0)
frow:GetScript("OnClick")(frow, "LeftButton")
check("a real click opens the quest", M.calls[1] and M.calls[1][1], "QuestMapFrame_OpenToQuestDetails")
check("saved: top left", S("focusPoint"), "TOPLEFT")
check("x", S("focusX"), 100)
M.state.cursorX = 300
local fw0 = S("focusWidth")
local fgrip
for _, f in ipairs(M.frames) do
    if f._parent == focus and f.icon and f.icon._texture and f.icon._texture:find("IconResize") then fgrip = f end
end
fgrip:GetScript("OnMouseDown")(fgrip)
M.state.cursorX = 340
fgrip:GetScript("OnUpdate")(fgrip, 0.1)
fgrip:GetScript("OnMouseUp")(fgrip)
check("corner widens it", S("focusWidth"), fw0 + 40)
-- From the centred default: the drag makes a corner the anchor first.
Settings.SetMany({ focusPoint = "TOP", focusX = 0, focusY = -140 })
focus._rect = { 1700, 600, 200, 80 }
M.state.cursorX = 100
fgrip:GetScript("OnMouseDown")(fgrip)
check("right half: anchored right", S("focusPoint"), "TOPRIGHT")
M.state.cursorX = 60
fgrip:GetScript("OnUpdate")(fgrip, 0.1)
fgrip:GetScript("OnMouseUp")(fgrip)
check("anchored right: dragging left widens", S("focusWidth"), fw0 + 80)
check("grip on the left then", fgrip._lastPoint[1], "BOTTOMLEFT")
Settings.Set("focusLocked", nil)
Settings.SetMany({ focusPoint = "TOP", focusX = 0, focusY = -140, focusWidth = 280 })
Settings.Set("focusEnabled", false)
M.RunTimers()
check("switched off", focus._shown, false)
Settings.Set("focusEnabled", nil)
M.superTracked = 0
M.RunTimers()

section("World map: more own options")
Settings.Set("mapStyle", "OWN")
local titleFs = wmf.BorderFrame.TitleContainer.TitleText
check("own: title font", titleFs._font[2], S("mapTitleSize"))
check("own: portrait hidden", wmf.BorderFrame.PortraitContainer._alpha, 0)
Settings.Set("mapPortrait", true)
check("own: portrait when wanted", wmf.BorderFrame.PortraitContainer._alpha, 1)
Settings.Set("mapPortrait", nil)
check("own: Blizzard's background faded", wmf.BorderFrame.Bg._alpha, 0)
Settings.Set("mapStyle", nil)
check("back: title colour", titleFs._textColor[2], 0.82)
check("back: Blizzard's background", wmf.BorderFrame.Bg._alpha, 1)
Settings.Set("mapScale", 80)
check("scaled", wmf._scale, 0.8)
Settings.Set("mapScale", nil)
check("scale undone", wmf._scale, 1)
ns.Window.Open()
check("focus options page", pcall(ns.Window.ShowPage, "focus"), true)
check("map options page", pcall(ns.Window.ShowPage, "map"), true)
ns.Window.Toggle()

section("One lock for tracker and focus frame")
Settings.SetMany({ locked = true, focusLocked = true })
header.lock:GetScript("OnClick")(header.lock)
check("header lock: tracker unlocked", S("locked"), false)
check("header lock: focus frame too", S("focusLocked"), false)
header.lock:GetScript("OnClick")(header.lock)
check("and locked together", S("focusLocked"), true)
SlashCmdList["FOREVERQUESTLOG"]("unlock")
check("/fql unlock: both", S("locked") == false and S("focusLocked") == false, true)
SlashCmdList["FOREVERQUESTLOG"]("lock")
check("/fql lock: both", S("locked") and S("focusLocked"), true)
Settings.Set("focusLocked", false)
check("focus frame alone still possible", S("locked") and not S("focusLocked"), true)
Settings.Set("focusLocked", true)

section("Use Blizzard's tracker")
Settings.Set("useBlizzard", true)
M.objectiveTracker._scale, M.objectiveTracker._alpha = 1, 1
ns.Blizzard.Hide()
check("then Blizzard's stays as it is", M.objectiveTracker._scale, 1)
Settings.Set("useBlizzard", nil)

section("Languages")
local base = ns.Locales.enUS
for code, strings in pairs(ns.Locales) do
    for key in pairs(base) do check(code .. " has " .. key, strings[key] ~= nil, true) end
    for key in pairs(strings) do check(code .. ": " .. key .. " is known", base[key] ~= nil, true) end
    for key, value in pairs(base) do
        local want = select(2, value:gsub("%%[ds]", ""))
        local got = strings[key] and select(2, strings[key]:gsub("%%[ds]", "")) or want
        check(code .. ": placeholders of " .. key, got, want)
    end
end
for key, value in pairs(ns.Locales.deDE) do
    for _, bad in ipairs({ "oess", "oesch", "oehe", "aende", "ueber", "fuer", "Rueck", "schliess" }) do
        check("no umlaut workaround in " .. key .. " (" .. bad .. ")", value:find(bad), nil)
    end
end
-- Every key the code uses exists in English.
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    for key in src:gmatch("L%.([A-Z][A-Z0-9_]+)") do check(f .. " uses known L." .. key, base[key] ~= nil, true) end
    for key in src:gmatch('"((OPT|PAGE|STYLE|TIP|MSG)_[A-Z0-9_]+)"') do check(f .. " uses known " .. key, base[key] ~= nil, true) end
end

section("No accidental globals")
local allowed = { SLASH_FOREVERQUESTLOG1 = true, SLASH_FOREVERQUESTLOG2 = true, ForeverQuestLogProfiles = true,
    ForeverQuestLogChar = true, ForeverQuestLog_OnAddonCompartmentClick = true,
    ForeverQuestLog_OnAddonCompartmentEnter = true, ForeverQuestLog_OnAddonCompartmentLeave = true }
for _, f in ipairs(tocFiles()) do
    local listing = io.popen("luac5.1 -l -p '" .. ROOT .. "/" .. f .. "' 2>/dev/null"):read("*a")
    for name in listing:gmatch("SETGLOBAL%s+%d+%s+[%-%d]*%s*; ([%w_]+)") do
        check(f .. " sets global " .. name, allowed[name] or false, true)
    end
end

section("Nothing private, no CVars")
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    check("no CVar storage in " .. f, src:find("SetCVar", 1, true), nil)
end
check("Blizzard's tracker and map: no field written", table.concat(M.violations, ","), "")

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
