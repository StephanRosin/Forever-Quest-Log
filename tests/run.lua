-- Tests for Forever Quest Log. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
ignoredByGamepad = {}
function SmartNavigation_MarkFrameIgnored(f) ignoredByGamepad[f] = true end
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
check("zones shown", zoneNames(), "Stranglethorn Vale |cffffd100(30-45)|r,Duskwood |cff3fbf3f(18-30)|r")
check("quests in zone order", questTitles(), "Tiger Mastery,Singing Blue Shards,Bloodscalp Ears,The Night Watch,Mor'Ladim")
local tiger = questRows()[1]
check("title with level", (tiger.title._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), "[34] Tiger Mastery")
check("level in its colour", tiger.title._text:find("|cff", 1, true) == 1, true)
check("map button for the quest", tiger.poi.questID, 185)
check("map button style: in progress", tiger.poi.icon._atlas, "Quest-In-Progress-Icon-yellow")
local blizzardPOI = 0
for _, f in ipairs(M.frames) do if f._template == "POIButtonTemplate" then blizzardPOI = blizzardPOI + 1 end end
check("map buttons are not Blizzard's (QuestCache taint)", blizzardPOI, 0)
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
check("complete: map button style", ears.poi.icon._atlas, "UI-QuestIcon-TurnIn-Normal")
ears.poi:GetScript("OnClick")(ears.poi, "LeftButton")
check("map button click focuses the quest", M.superTracked, ears.quest.id)
ears.poi:GetScript("OnClick")(ears.poi, "LeftButton")
check("second click clears the focus", M.superTracked, 0)
ears.poi:GetScript("OnClick")(ears.poi, "LeftButton")
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
Settings.Set("collapseHides", true)
ns.Tracker.ToggleCollapse()
M.RunTimers()
check("collapse hides: frame gone", frame._shown, false)
Settings.Set("locked", false)
M.RunTimers()
check("collapse hides: unlocked still shows", frame._shown, true)
Settings.Set("locked", true)
ns.Tracker.ToggleCollapse()
M.RunTimers()
check("collapse hides: key brings it back", frame._shown, true)
Settings.Set("collapseHides", nil)
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
M.calls = {}
M.state.combat = true
tiger:GetScript("OnClick")(tiger, "LeftButton")
check("in combat: the map waits (ShowUIPanel would be blocked)", #M.calls, 0)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("after combat: the map opens", lastCall(), "QuestMapFrame_OpenToQuestDetails:185")
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
M.quest(185).party = 1
tiger:GetScript("OnEnter")(tiger)
check("hover in a group: party progress", lastCall(), "SetQuestPartyProgress:185")
M.quest(185).party = nil
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
Settings.SetMany({ height = 120, showScrollbar = false })
relayout()
check("switched off: no bar though there is something to scroll", frame.thumb._shown, false)
Settings.Set("height", nil)
Settings.Set("showScrollbar", nil)
relayout()

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
check("built on the map", ns.WorldMap ~= nil, true)
check("no hook on Blizzard's map (taint)", wmf._scripts.OnShow, nil)
check("Blizzard's look by default: border untouched", wmf.BorderFrame.NineSlice._alpha, 1)
M.PanelManagerPlaces()
wmf._shown = true
local handle
for _, f in ipairs(M.frames) do if f._parent == WorldMapFrame and f._scripts.OnMouseDown then handle = f end end
handle._scripts.OnShow(handle)
check("not dragged yet: Blizzard's place", wmf._lastPoint[4], 16)
check("drag handle on the title bar", handle ~= nil, true)
check("controller navigation skips the map handle", ignoredByGamepad[handle], true)
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
-- Another addon (OpenMap) puts its own place back whenever SetPoint runs:
-- we step back instead of moving the map twenty times a second.
local setPoint = wmf.SetPoint
local othersPlace = 0
wmf.SetPoint = function(self, ...)
    setPoint(self, ...)
    othersPlace = othersPlace + 1
    setPoint(self, "TOPLEFT", UIParent, "TOPLEFT", 50, -50)
end
M.chat = {}
Settings.SetMany({ mapPlaced = true, mapPoint = "TOPLEFT", mapX = 400, mapY = -100 })
handle._scripts.OnUpdate(handle, 0.1)
handle._scripts.OnUpdate(handle, 0.1)
check("another addon places the map: we tried once", othersPlace, 1)
check("then left it there", wmf._lastPoint[4], 50)
check("said so once", #M.chat, 1)
check("drag handle off", handle._mouse, false)
wmf.SetPoint = setPoint
ns.WorldMap.yielded = false
handle:EnableMouse(true)
Settings.SetMany({ mapPlaced = nil, mapPoint = nil, mapX = nil, mapY = nil })
wmf._shown = false

section("Quest window")
local qf = M.questFrame
local qfHandle
for _, f in ipairs(M.frames) do if f._parent == QuestFrame and f._scripts.OnMouseDown then qfHandle = f end end
check("drag handle on the title bar", qfHandle ~= nil, true)
check("controller navigation skips the quest window handle", ignoredByGamepad[qfHandle], true)
check("no hook on Blizzard's quest window (taint)", qf._scripts.OnShow, nil)
M.PanelManagerPlacesQuestFrame()
qfHandle._scripts.OnShow(qfHandle)
check("not dragged yet: Blizzard's place", qf._lastPoint[4], 16)
qfHandle._scripts.OnMouseDown(qfHandle, "LeftButton")
check("dragging moves it", qf._moving, true)
qf._rect = { 1200, 400, 338, 496 }
qfHandle._scripts.OnMouseUp(qfHandle, "LeftButton")
check("dropped: right half, top half", S("questDialogPoint"), "TOPRIGHT")
check("x from the right edge", S("questDialogX"), 1538 - 1920)
check("y from the top", S("questDialogY"), 896 - 1080)
M.PanelManagerPlacesQuestFrame()
qfHandle._scripts.OnShow(qfHandle)
check("opens where it was left", qf._lastPoint[1] .. "," .. qf._lastPoint[4], "TOPRIGHT,-382")
M.PanelManagerPlacesQuestFrame()
qfHandle._scripts.OnUpdate(qfHandle, 0.1)
check("Blizzard places it again: put back", qf._lastPoint[4], -382)
-- The greeting shares that place, whichever of the two was dragged.
local gf = M.gossipFrame
local gfHandle
for _, f in ipairs(M.frames) do if f._parent == GossipFrame and f._scripts.OnMouseDown then gfHandle = f end end
check("greeting: drag handle", gfHandle ~= nil, true)
M.PanelManagerPlacesQuestFrame(gf)
gfHandle._scripts.OnShow(gfHandle)
check("greeting opens at the quest window's place", gf._lastPoint[1] .. "," .. gf._lastPoint[4], "TOPRIGHT,-382")
gfHandle._scripts.OnMouseDown(gfHandle, "LeftButton")
check("greeting: dragging moves it", gf._moving, true)
gf._rect = { 1000, 400, 338, 496 }
gfHandle._scripts.OnMouseUp(gfHandle, "LeftButton")
check("greeting: dropped", S("questDialogX"), 1338 - 1920)
M.PanelManagerPlacesQuestFrame()
qfHandle._scripts.OnShow(qfHandle)
check("quest window follows the greeting", qf._lastPoint[4], -582)
-- Walking away from the NPC closes the window in the middle of a drag.
qfHandle._scripts.OnMouseDown(qfHandle, "LeftButton")
qf._rect = { 100, 400, 338, 496 }
qfHandle._scripts.OnHide(qfHandle)
check("closed mid-drag: drag ended", qf._moving, false)
check("closed mid-drag: position kept", S("questDialogPoint") .. "," .. S("questDialogX"), "TOPLEFT,100")
ns.QuestDialog.ResetPosition()
M.PanelManagerPlacesQuestFrame()
qfHandle._scripts.OnUpdate(qfHandle, 0.1)
check("reset: Blizzard's place stays", qf._lastPoint[4], 16)
Settings.Set("questDialogMove", false)
qfHandle._scripts.OnMouseDown(qfHandle, "LeftButton")
check("moving off: no drag", qf._moving, false)
Settings.Set("questDialogMove", nil)
-- Another addon that puts its own place back: we step back once.
local qfSetPoint = qf.SetPoint
qf.SetPoint = function(self, ...)
    qfSetPoint(self, ...)
    qfSetPoint(self, "TOPLEFT", UIParent, "TOPLEFT", 50, -50)
end
M.chat = {}
Settings.SetMany({ questDialogPlaced = true, questDialogPoint = "TOPLEFT", questDialogX = 400, questDialogY = -100 })
qfHandle._scripts.OnUpdate(qfHandle, 0.1)
qfHandle._scripts.OnUpdate(qfHandle, 0.1)
check("another addon places it: left there", qf._lastPoint[4], 50)
check("said so once", #M.chat, 1)
check("drag handle off", qfHandle._mouse, false)
check("the greeting still moves", gfHandle._mouse, true)
qf.SetPoint = qfSetPoint
ns.QuestDialog.yielded[QuestFrame] = nil
qfHandle:EnableMouse(true)
Settings.SetMany({ questDialogPlaced = nil, questDialogPoint = nil, questDialogX = nil, questDialogY = nil })

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
do
    local row = blizzardUpdate("[30] Apothecary Zarah")
    row.questID = 185
    QuestLogQuests_Update()
    check("list: no limit, title stays", row.Text:GetText(), "[30] Apothecary Zarah")
    M.timed = { [185] = { 2700, 900 } }
    QuestLogQuests_Update()
    check("list: time behind the title", row.Text:GetText(), "[30] Apothecary Zarah (30:00)")
    QuestLogQuests_Update()
    check("list: not appended twice", row.Text:GetText(), "[30] Apothecary Zarah (30:00)")
    local ticker = ns.QuestLogStyle.ticker
    M.timed[185] = { 2700, 901 }
    ticker:GetScript("OnUpdate")(ticker, 0.5)
    check("list: waits for the second", row.Text:GetText(), "[30] Apothecary Zarah (30:00)")
    ticker:GetScript("OnUpdate")(ticker, 0.6)
    check("list: counts down", row.Text:GetText(), "[30] Apothecary Zarah (29:59)")
    QuestScrollFrame:Hide()
    M.timed[185] = { 2700, 902 }
    ticker:GetScript("OnUpdate")(ticker, 1.1)
    check("list hidden: no tick", row.Text:GetText(), "[30] Apothecary Zarah (29:59)")
    QuestScrollFrame:Show()
    M.timed[185] = { 2700, 2700 }
    ticker:GetScript("OnUpdate")(ticker, 1.1)
    check("list: time up, title clean", row.Text:GetText(), "[30] Apothecary Zarah")
    M.timed = nil
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

section("Ideas from MonkeyQuest")
check("default: finished objectives dimmed, not hidden", Settings.DEFAULTS.showDoneObjectives, true)
check("default: completed quests shown", Settings.DEFAULTS.hideCompleteQuests, false)
check("default: objective colours unchanged", Settings.DEFAULTS.objectiveProgressColors, false)
do
    local row = ns.Rows.NewQuestRow(UIParent)
    local function layout(line)
        ns.Rows.LayoutQuest(row, { title = "T", objectives = { line } }, 200, 1)
        local l = row.lines[1]
        return l.text._points.TOPLEFT[3], l.icon:IsShown() and l.icon._points.LEFT[3] or nil
    end
    local open, done = { text = "open" }, { text = "done", check = true }
    local base = layout(open)
    check("objective indent: off by default", Settings.DEFAULTS.objectiveIndent, 0)
    local text, icon = layout(done)
    check("objective indent 0: check mark at the edge", icon, base)
    check("objective indent 0: its text behind it", text, base + 15)
    Settings.Set("objectiveIndent", 25)
    text, icon = layout(open)
    check("objective indent 25: open text moves", text, base + 25)
    check("objective indent 25: no check mark appears", icon, nil)
    text, icon = layout(done)
    check("objective indent 25: checked text lines up", text, base + 25)
    check("objective indent 25: check mark right before it", icon, base + 10)
    Settings.Set("objectiveIndent", nil)
end
local all = Data.Quests()
check("hide completed quests: one less", #Sort.Build(all, { hideComplete = true }), #all - 1)
for _, entry in ipairs(Sort.Build(all, { hideComplete = true })) do
    check("hide completed quests: " .. entry.quest.title, entry.quest.isComplete, false)
end
local talkTo = { objectives = {}, overview = "Speak to Kin'weelay." }
do
    check("time text: minutes", ns.Rows.TimeText(2700), "45:00")
    check("time text: hours", ns.Rows.TimeText(3753), "1:02:33")
    check("time text: rounds up", ns.Rows.TimeText(59.2), "1:00")
    local function timed(extra)
        local q = { objectives = {}, timeLeft = 1500, isComplete = false }
        for k, v in pairs(extra or {}) do q[k] = v end
        return ns.Rows.QuestLines(q)
    end
    check("timer: first line", timed()[1].text, ns.L.TIME_LEFT:format("25:00"))
    check("timer: no warning yet", timed()[1].color, nil)
    check("timer: red in the last minute", timed({ timeLeft = 60 })[1].color[1], 1)
    check("timer: also on a complete quest", timed({ isComplete = true })[1].text, ns.L.TIME_LEFT:format("25:00"))
    check("timer: complete keeps its line", timed({ isComplete = true })[2].style, "done")

    M.timed = { [185] = { 2700, 900 }, [605] = { 2700, 2700 } }
    local list = ns.Data.Quests()
    local byID = {}
    for _, q in ipairs(list) do byID[q.id] = q end
    check("timed quest: seconds left", byID[185].timeLeft, 1800)
    check("time is up: no line", byID[605].timeLeft, nil)
    check("no time limit: no line", byID[189].timeLeft, nil)

    -- On screen: the line counts down once a second, and stops ticking without a timer.
    local tracker = ns.Tracker.frame
    local function timerLine()
        for _, r in ipairs(questRows()) do
            for _, line in ipairs(r.lines or {}) do
                local t = line.text and line.text._shown ~= false and line.text:GetText()
                if t and t:find(ns.L.TIME_LEFT:format(""), 1, true) then return t end
            end
        end
    end
    ns.Tracker.Refresh(); M.RunTimers()
    check("on screen: time left", timerLine(), ns.L.TIME_LEFT:format("30:00"))
    M.timed[185] = { 2700, 901 }
    tracker:GetScript("OnUpdate")(tracker, 1.1); M.RunTimers()
    check("on screen: counts down", timerLine(), ns.L.TIME_LEFT:format("29:59"))
    M.timed = nil
    tracker:GetScript("OnUpdate")(tracker, 1.1); M.RunTimers()
    check("timer gone: nothing ticks", ns.Tracker.hasTimedQuest, false)
end
check("no objectives: the quest text", ns.Rows.QuestLines(talkTo)[1].text, "Speak to Kin'weelay.")
Settings.Set("showOverview", false)
check("no objectives, option off: nothing", #ns.Rows.QuestLines(talkTo), 0)
Settings.Set("showOverview", true)
local function rgb(c) return table.concat(c, ",") end
check("progress colour 0: red", rgb(ns.Rows.ProgressColor(0)), "1,0,0")
check("progress colour 1/2: yellow", rgb(ns.Rows.ProgressColor(0.5)), "1,1,0")
check("progress colour 1: green", rgb(ns.Rows.ProgressColor(1)), "0,1,0")

M.quest(185).overview = "Kill 10 Young Stranglethorn Tigers."
relayout()
M.calls = {}
local hovered
for _, row in ipairs(questRows()) do if row.quest and row.quest.id == 185 then hovered = row end end
hovered:GetScript("OnEnter")(hovered)
check("tooltip: title", GameTooltip._text, "Tiger Mastery")
check("tooltip: quest text", GameTooltip._lines[1], "Kill 10 Young Stranglethorn Tigers.")
check("tooltip alone: no party progress", #M.calls, 0)
M.state.group = true
M.quest(185).party = 2
hovered:GetScript("OnEnter")(hovered)
check("tooltip in a group: party progress after the text", lastCall(), "SetQuestPartyProgress:185")
Settings.Set("questTooltip", false)
M.state.group = false
M.calls = {}
GameTooltip._text = nil
hovered:GetScript("OnEnter")(hovered)
check("tooltip off, alone: nothing", GameTooltip._text, nil)
Settings.Set("questTooltip", true)
M.quest(185).party, M.quest(185).overview = nil, nil

ForeverQuestLog_Binding("HIDECOMPLETE")
check("key: hide completed quests", S("hideCompleteQuests"), true)
ForeverQuestLog_Binding("HIDECOMPLETE")
check("key: show them again", S("hideCompleteQuests"), false)
local bindings = io.open(ROOT .. "/Bindings.xml"):read("*a")
for name, action in bindings:gmatch('name="([%w_]+)".-ForeverQuestLog_Binding%("(%u+)"%)') do
    check(name .. " has a label", type(_G["BINDING_NAME_" .. name]), "string")
    check(name .. " runs", pcall(ForeverQuestLog_Binding, action), true)
end
check("bindings header", BINDING_HEADER_FOREVERQUESTLOG, "Forever Quest Log")

section("Keys page")
ns.Window.Open("keys")
local keyRow = rowFor("Lock / unlock", "button")
check("keys page: a row per action", keyRow ~= nil, true)
check("not bound yet", keyRow.button.text._text, "Not bound")
keyRow.button:GetScript("OnClick")(keyRow.button, "LeftButton")
check("listening", keyRow.button.text._text, "Press a key ...")
keyRow.button:GetScript("OnKeyDown")(keyRow.button, "LSHIFT")
check("a modifier alone: still listening", keyRow.button.listening, true)
M.state.shift = true
keyRow.button:GetScript("OnKeyDown")(keyRow.button, "L")
M.state.shift = false
check("bound with its modifier", M.bindings["SHIFT-L"], "FOREVERQUESTLOG_LOCK")
check("shown", keyRow.button.text._text, "SHIFT-L")
check("saved", lastCall(), "SaveBindings:1")
M.bindings["F7"] = "TOGGLEWORLDMAP"
M.chat = {}
keyRow.button:GetScript("OnClick")(keyRow.button, "LeftButton")
keyRow.button:GetScript("OnKeyDown")(keyRow.button, "F7")
check("a new key replaces the old one", M.bindings["SHIFT-L"], nil)
check("taken from another action: said so", #M.chat > 0, true)
keyRow.button:GetScript("OnClick")(keyRow.button, "LeftButton")
keyRow.button:GetScript("OnKeyDown")(keyRow.button, "ESCAPE")
check("escape: key kept", M.bindings["F7"], "FOREVERQUESTLOG_LOCK")
keyRow.button:GetScript("OnClick")(keyRow.button, "RightButton")
check("right click: no key", M.bindings["F7"], nil)
check("right click: shown", keyRow.button.text._text, "Not bound")
M.state.combat = true
ns.Keys.Set("LOCK", "F8")
check("combat: nothing bound", M.bindings["F8"], nil)
M.state.combat = false
ns.Window.Toggle()

section("Announcement")
do
    local News = ns.News
    local function shown()
        local n = 0
        for _, popup in ipairs(M.popups) do
            if popup.which == "FOREVERQUESTLOG_NEWS" then n = n + 1 end
        end
        return n
    end
    local function loadingDone()
        M.Fire("LOADING_SCREEN_DISABLED")
        M.RunTimers()
    end
    check("fresh install: nothing shown", shown(), 0)
    check("fresh install: recorded", ForeverQuestLogProfiles.newsSeen, News.VERSION)
    loadingDone()
    check("seen: nothing shown", shown(), 0)
    ForeverQuestLogProfiles.newsSeen = nil
    M.state.combat = true
    loadingDone()
    check("update, in combat: waits", shown(), 0)
    check("update, in combat: not recorded", ForeverQuestLogProfiles.newsSeen, nil)
    M.state.combat = false
    M.Fire("PLAYER_REGEN_ENABLED")
    check("update: shown after combat", shown(), 1)
    check("update: names the version", M.popups[#M.popups].text:find(News.VERSION, 1, true) ~= nil, true)
    check("update: recorded", ForeverQuestLogProfiles.newsSeen, News.VERSION)
    loadingDone()
    check("only once", shown(), 1)
    ForeverQuestLogProfiles.newsSeen = "0.3.7"
    M.popupBlocked = true
    loadingDone()
    check("blocked popup: not recorded", ForeverQuestLogProfiles.newsSeen, "0.3.7")
    M.popupBlocked = nil
    loadingDone()
    check("blocked popup: shown next time", shown(), 2)
    for code, strings in pairs(ns.Locales) do
        check(code .. ": news text has no format codes", strings.NEWS_TEXT:find("%", 1, true), nil)
    end
end

section("Task lists")
do
    local Tasks = ns.Tasks
    check("search: real item", Tasks.Search("Runecloth")[1].id, 14047)
    check("search: nothing under 3 letters", #Tasks.Search("Ru"), 0)
    check("search: 3 letters do", #Tasks.Search("Run") > 0, true)
    check("search: not case sensitive", Tasks.Search("rUNECLOTH")[1].id, 14047)
    check("search: stops at the maximum", #Tasks.Search("potion"), Tasks.MAX_RESULTS)
    local mana = Tasks.Search("Mana Potion")
    check("search: starting with it comes first", mana[1].name:sub(1, 11), "Mana Potion")
    check("search: inside a name too", (function()
        for _, item in ipairs(mana) do if item.name:find("^%a+ Mana Potion") then return true end end
    end)(), true)
    check("search: Blizzard's leftovers are gone", #Tasks.Search("Deprecated"), 0)
    check("exact name", Tasks.FindExact(" linen cloth ").id, 2589)
    check("no exact name", Tasks.FindExact("Linen"), nil)
    -- A capital umlaut: lower() must fold it for the German list.
    local chunk = loadfile(ROOT .. "/ItemNames/deDE.lua")
    local savedLocale, german = M.locale, {}
    M.locale = "deDE"
    chunk(ADDON, german)
    M.locale = savedLocale
    check("German names are there", german.ItemNames:find("14047\t1\tRunenstoff\n", 1, true) ~= nil, true)
    check("names load in their language only", (function()
        local other = {}
        chunk(ADDON, other)
        return other.ItemNames
    end)(), nil)

    check("no lists: entries unchanged", #Tasks.Entries(), 0)
    check("empty name refused", Tasks.AddList("   "), nil)
    local list = Tasks.AddList(" Shopping ")
    check("name trimmed", list.name, "Shopping")
    local cloth = Tasks.FindExact("Runecloth")
    M.bags, M.bank = { [14047] = 7 }, { [14047] = 20 }
    Tasks.AddItem(list, cloth, 20)
    check("item line: count from the bags", Tasks.Line(list.entries[1]).cur, 7)
    check("item line: open", Tasks.Line(list.entries[1]).done, false)
    check("item line: empty box", Tasks.Line(list.entries[1]).icon, "Box")
    check("bank is off by default", Settings.DEFAULTS.taskCountBank, false)
    Settings.Set("taskCountBank", true)
    check("bank counted when asked", Tasks.Line(list.entries[1]).done, true)
    check("item line: ticks itself", Tasks.Line(list.entries[1]).icon, "BoxChecked")
    Settings.Set("taskCountBank", nil)
    Tasks.AddItem(list, cloth, 5)
    check("same item: no second line", #list.entries, 1)
    check("same item: new amount", list.entries[1].goal, 5)
    check("item done without the bank", Tasks.Line(list.entries[1]).done, true)
    Tasks.AddItem(list, cloth, 20)
    Tasks.Toggle(list.entries[1])
    check("an item cannot be ticked by hand", Tasks.Line(list.entries[1]).done, false)
    check("amount refused: not a number", Tasks.SetAmount(list.entries[1], "x"), false)
    check("amount refused: zero", Tasks.SetAmount(list.entries[1], "0"), false)
    check("empty text refused", Tasks.AddText(list, " "), false)
    Tasks.AddText(list, "See the trainer")
    local note = list.entries[2]
    check("text line: open", Tasks.Line(note).done, false)
    local rows = Tasks.Entries()
    check("rows: head and two entries", #rows, 3)
    check("rows: head first", rows[1].kind, "list")
    check("rows: count finished / all", rows[1].count, "0/2")
    Tasks.Toggle(note)
    check("text line: ticked by hand", Tasks.Line(note).done, true)
    check("rows: count follows", Tasks.Entries()[1].count, "1/2")
    Tasks.ToggleList(list)
    check("collapsed: only the head", #Tasks.Entries(), 1)
    check("collapsed: count stays", Tasks.Entries()[1].count, "1/2")
    Tasks.ToggleList(list)
    -- Order: entries within their list, lists among the lists.
    local first, second = list.entries[1], list.entries[2]
    check("move: to the end", Tasks.MoveEntry(list, first, nil), true)
    check("move: now second", list.entries[2], first)
    Tasks.MoveEntry(list, first, second)
    check("move: in front of another", list.entries[1], first)
    check("move: onto itself does nothing", Tasks.MoveEntry(list, first, first), false)
    local other = Tasks.AddList("Other")
    Tasks.MoveList(other, list)
    check("move list: in front", Tasks.Lists()[1], other)
    Tasks.MoveList(other, nil)
    check("move list: to the end", Tasks.Lists()[2], other)
    Tasks.RemoveList(other)

    local tracked = Data.Quests()
    Settings.Set("groupByZone", false)
    local drawn = ns.Tracker.Entries(tracked, {})
    check("tracker: the list on top", drawn[1].kind, "list")
    local head = ns.Rows.NewZoneRow(UIParent)
    ns.Rows.LayoutZone(head, drawn[1], 200, list, Tasks.ToggleList)
    check("list head: +, undock and gear shown", head.add:IsShown() and head.undock:IsShown() and head.gear:IsShown(), true)
    check("list head: undock beside the +", head.undock._points.LEFT[1], head.add)
    local opened = #M.menus
    head.gear:GetScript("OnClick")(head.gear)
    check("list head: the gear opens the menu", #M.menus, opened + 1)
    check("list head: the menu has no second way to add", M.menus[#M.menus].entries[2].text, ns.L.TASK_RENAME)
    local openAdd, addedTo = ns.TaskUI.OpenAdd, nil
    ns.TaskUI.OpenAdd = function(target) addedTo = target end
    head.add:GetScript("OnClick")(head.add)
    ns.TaskUI.OpenAdd = openAdd
    check("list head: + opens adding to this list", addedTo, list)
    ns.Rows.LayoutZone(head, { name = "Duskwood", count = 1 }, 200, "Duskwood", function() end)
    check("a zone on the same row: no + or gear", head.add:IsShown() or head.gear:IsShown() or head.undock:IsShown(), false)
    check("a zone on the same row: rule back at the name", head.rule._points.LEFT[1], head.name)
    check("tracker: quests under their own header", drawn[4].key, "quests")
    check("tracker: that header counts them", drawn[4].count, #drawn - 4)
    check("tracker: then the quests", drawn[5].kind, "quest")
    local st = ns.CharState()
    st.instance, st.onlyHere = "Duskwood", true
    check("this dungeon: no lists", ns.Tracker.Entries(tracked, {})[1].kind ~= "list", true)
    st.instance, st.onlyHere = nil, nil
    Settings.Set("groupByZone", true)
    drawn = ns.Tracker.Entries(tracked, {})
    check("zones: no extra quest header", drawn[4].kind, "zone")
    Settings.Set("groupByZone", nil)
    ns.Tracker.Layout()
    check("layout with a list draws", true, true)
    -- Undocked: a window of its own, the tracker without the list; closing docks it.
    local undockHead = ns.Rows.NewZoneRow(UIParent)
    local listEntry
    for _, e in ipairs(ns.Tracker.Entries(Data.Quests(), {})) do if e.list == list and e.kind == "list" then listEntry = e end end
    ns.Rows.LayoutZone(undockHead, listEntry, 200, list, Tasks.ToggleList)
    undockHead.undock:GetScript("OnClick")(undockHead.undock)
    check("undocked: not in the tracker", (function()
        for _, e in ipairs(Tasks.Entries()) do if e.list == list then return true end end
        return false
    end)(), false)
    local win = ns.Notes.windows[list]
    check("undocked: a window", win ~= nil and win:IsShown(), true)
    check("undocked: a row per entry", (function()
        local n = 0
        for _, r in ipairs(win.rows) do if r:IsShown() then n = n + 1 end end
        return n
    end)(), #list.entries)
    check("undocked: name and count", win.name:GetText(), "Shopping  " .. (function()
        local d = 0
        for _, e in ipairs(list.entries) do if Tasks.Line(e).done then d = d + 1 end end
        return d
    end)() .. "/" .. #list.entries)
    -- Dragging inside the note: the first entry below the second.
    local noteTop, noteLow = win.rows[1], win.rows[2]
    noteTop._rect, noteLow._rect = { 0, 500, 200, 20 }, { 0, 480, 200, 20 }
    local movedTask = noteTop.task
    check("note: rows can be dragged", noteTop._drag, true)
    M.state.time = 5
    noteTop:GetScript("OnDragStart")(noteTop)
    M.state.cursorY = 470
    noteTop:GetScript("OnDragStop")(noteTop)
    check("note: dropped below", list.entries[2], movedTask)
    Tasks.MoveEntry(list, movedTask, list.entries[1])
    M.state.cursorY = nil
    win._rect = { 300, 400, 320, 260 }
    win:SetSize(320, 260)
    win.grip:GetScript("OnMouseUp")(win.grip)
    check("resized: kept on the list", list.note.w .. "x" .. list.note.h, "320x260")
    check("moved: kept on the list", list.note.x, 300)
    local menus = #M.menus
    ns.TaskUI.ListMenu(UIParent, list)
    check("undocked: the menu docks", (function()
        for _, e in ipairs(M.menus[menus + 1].entries) do if e.text == ns.L.TASK_DOCK then return true end end
        return false
    end)(), true)
    win.close:GetScript("OnClick")(win.close)
    check("closed: docked again", list.undocked, nil)
    check("closed: the window is gone", win:IsShown(), false)
    check("closed: back in the tracker", Tasks.Entries()[1].list, list)
    Tasks.Undock(list)
    check("undocked again: where it was", ns.Notes.windows[list] and list.note.w, 320)
    Tasks.Dock(list)
    M.RunTimers()

    -- Dragging in the tracker: a task below the other, then back.
    local taskRows = {}
    for _, f in ipairs(M.frames) do
        if f:IsShown() and f.task and f.list == list and f._parent ~= win.child then taskRows[#taskRows + 1] = f end
    end
    check("drag: both tasks drawn", #taskRows, 2)
    local top, low = taskRows[1], taskRows[2]
    top._rect, low._rect = { 0, 500, 200, 20 }, { 0, 480, 200, 20 }
    local firstTask = top.task
    check("drag: rows can be dragged", top._drag, true)
    M.state.time = 10
    top:GetScript("OnDragStart")(top)
    M.state.cursorY = 470
    top:GetScript("OnDragStop")(top)
    check("drag: dropped below the last", list.entries[2], firstTask)
    local done = firstTask.done
    top:GetScript("OnClick")(top, "LeftButton")
    check("drag: the release is no tick", firstTask.done, done)
    M.state.time = 11
    M.RunTimers()
    check("drag: relaid, the moved task is the lower row", low.task, firstTask)
    low:GetScript("OnDragStart")(low)
    M.state.cursorY = 515
    low:GetScript("OnDragStop")(low)
    check("drag: back on top", list.entries[1], firstTask)
    M.state.cursorY = nil

    -- The window: suggestion or text from the same field.
    local p = ns.TaskUI.OpenAdd(list)
    local enter = p.edit:GetScript("OnEnterPressed")
    local before = #list.entries
    p.edit:SetText("Buy a mount")
    enter(p.edit)
    check("Enter on free text: a text entry", list.entries[before + 1].text, "Buy a mount")
    check("field cleared for the next", p.edit:GetText(), "")
    p.edit:SetText("Linen Cloth")
    p.amount:SetText("12")
    enter(p.edit)
    check("Enter on an exact name: the item", list.entries[before + 2].itemID, 2589)
    check("with the amount", list.entries[before + 2].goal, 12)
    p.edit:SetText("Light Lea")
    p.edit:GetScript("OnTextChanged")(p.edit, true)
    check("typing suggests", p.list:IsShown(), true)
    p.edit:GetScript("OnArrowPressed")(p.edit, "DOWN")
    check("arrow down selects the first", p.selection, 1)
    p.edit:GetScript("OnArrowPressed")(p.edit, "UP")
    check("arrow up wraps", p.selection, #p.results)
    p.edit:GetScript("OnArrowPressed")(p.edit, "DOWN")
    enter(p.edit)
    check("Enter on a selection: that item", list.entries[before + 3].itemID, 2318)
    -- Zones: the name goes into the text, Enter then adds the text.
    p.edit:SetText("Quests in tana")
    p.edit:GetScript("OnTextChanged")(p.edit, true)
    check("zone: suggested from the end of the text", p.results[1].name, "Tanaris")
    check("zone: once, though two maps carry the name", #ns.Tasks.Search("Quests in tana"), 1)
    p.edit:GetScript("OnArrowPressed")(p.edit, "DOWN")
    enter(p.edit)
    check("zone: put into the text", p.edit:GetText(), "Quests in Tanaris")
    check("zone: no entry yet", #list.entries, before + 3)
    check("zone: suggestions gone", p.list:IsShown(), false)
    enter(p.edit)
    check("zone: Enter adds the text", list.entries[before + 4].text, "Quests in Tanaris")
    local placed = list.entries[before + 4]
    check("zone: remembered with its map", placed.place and placed.place.mapID, 1446)
    check("zone: symbol in front, range behind", ns.Tasks.Line(placed).text,
        ns.Tasks.PLACE_SYMBOL.zone .. " Quests in Tanaris |cffff1919(40-50)|r")
    Settings.Set("zoneLevels", false)
    check("zone: range off", ns.Tasks.Line(placed).text, ns.Tasks.PLACE_SYMBOL.zone .. " Quests in Tanaris")
    Settings.Set("zoneLevels", nil)
    placed.done = true
    check("zone: no range once done", ns.Tasks.Line(placed).text, ns.Tasks.PLACE_SYMBOL.zone .. " Quests in Tanaris")
    placed.done = nil
    local menus = #M.menus
    ns.TaskUI.EntryMenu(UIParent, list, placed)
    local showMap
    for _, e in ipairs(M.menus[menus + 1].entries) do if e.text == ns.L.TASK_SHOW_MAP then showMap = e end end
    check("zone: the menu shows it on the map", showMap ~= nil, true)
    -- Dungeons: their own symbol, no map.
    p.edit:SetText("Run deadmi")
    p.edit:GetScript("OnTextChanged")(p.edit, true)
    check("dungeon: kind", p.results[1].kind, "dungeon")
    p.edit:GetScript("OnArrowPressed")(p.edit, "DOWN")
    enter(p.edit)
    enter(p.edit)
    local run = list.entries[before + 5]
    check("dungeon: symbol", ns.Tasks.Line(run).text, ns.Tasks.PLACE_SYMBOL.dungeon .. " Run Deadmines |cff3fbf3f(17-26)|r")
    check("dungeon: no map", run.place.mapID, nil)
    ns.TaskUI.EntryMenu(UIParent, list, run)
    check("dungeon: no map entry", (function()
        for _, e in ipairs(M.menus[#M.menus].entries) do if e.text == ns.L.TASK_SHOW_MAP then return true end end
        return false
    end)(), false)
    check("raid: kind", ns.Tasks.Search("Clear core")[1].kind, "raid")
    ns.Tasks.RemoveEntry(list, run)
    check("typed by hand: no symbol", (function()
        ns.Tasks.AddText(list, "Visit Tanaris")
        local e = list.entries[#list.entries]
        ns.Tasks.RemoveEntry(list, e)
        return e.place
    end)(), nil)
    check("zone: continents are not zones", (function()
        for _, r in ipairs(ns.Tasks.Search("Kalim")) do if r.zone then return true end end
        return false
    end)(), false)
    check("dungeon: shipped, suggested", ns.Tasks.Search("Run deadmi")[1].name, "Deadmines")
    check("raid: found by a later word", ns.Tasks.Search("Clear core")[1].name, "Molten Core")
    check("dungeon: a name in both lists is a raid (Naxxramas)", (function()
        for _, name in ipairs(ns.PlaceNames.dungeons) do if name == "Naxxramas" then return "dungeon" end end
        for _, name in ipairs(ns.PlaceNames.raids) do if name == "Naxxramas" then return "raid" end end
    end)(), "raid")
    check("zone: the whole text too", ns.Tasks.Search("strangle")[1].name, "Stranglethorn Vale")
    -- Editing a text entry suggests zones as well.
    local edited = list.entries[before + 4]
    local pe = ns.TaskUI.OpenEdit(edited)
    pe.edit:SetText("Quests in Ashen")
    pe.edit:GetScript("OnTextChanged")(pe.edit, true)
    check("edit: zone suggested", pe.results[1] and pe.results[1].name, "Ashenvale")
    check("edit: no items", #pe.results, 1)
    pe.edit:GetScript("OnArrowPressed")(pe.edit, "DOWN")
    enter(pe.edit)
    check("edit: zone put into the text", pe.edit:GetText(), "Quests in Ashenvale")
    check("edit: not saved yet", edited.text, "Quests in Tanaris")
    enter(pe.edit)
    check("edit: Enter saves", edited.text, "Quests in Ashenvale")
    check("edit: the new place", edited.place.name, "Ashenvale")
    ns.TaskUI.OpenEdit(edited)
    pe.edit:SetText("Quests in Ashenvale today")
    enter(pe.edit)
    check("edit: the place stays while its name does", edited.place and edited.place.name, "Ashenvale")
    ns.TaskUI.OpenEdit(edited)
    pe.edit:SetText("Something else")
    enter(pe.edit)
    check("edit: name gone, symbol gone", edited.place, nil)
    ns.Tasks.RemoveEntry(list, list.entries[before + 4])
    -- Where the player is: a place entry there is coloured like a quest title.
    ns.Tasks.AddText(list, "Quests in Tanaris", { kind = "zone", name = "Tanaris", mapID = 1446 })
    local there = list.entries[#list.entries]
    M.state.zone = "Elwynn Forest"
    check("here: elsewhere, plain", ns.Tasks.Line(there).color, nil)
    M.state.zone = "tanaris"
    check("here: in the zone, title colour", ns.Tasks.Line(there).color, Settings.Get("titleColor"))
    there.done = true
    check("here: done, plain", ns.Tasks.Line(there).color, nil)
    M.state.zone = nil
    ns.Tasks.RemoveEntry(list, there)
    -- Goals: suggested for a number with a word, counted by the game.
    local function goals(text)
        local kinds = {}
        for _, r in ipairs(ns.Tasks.Search(text)) do if r.goal then kinds[#kinds + 1] = r.goal .. (r.amount or "") end end
        return table.concat(kinds, ",")
    end
    check("goal: level", goals("Level 50"), "level50")
    check("goal: lvl", goals("lvl 50"), "level50")
    check("goal: gold", goals("100 gold"), "money100")
    check("goal: 100g", goals("100g"), "money100")
    check("goal: not inside a word", goals("Leveln in Tanaris"), "")
    check("goal: the word alone, amount from the box", goals("Gold"), "money")
    check("goal: the word alone, any case", goals("level"), "level")
    check("goal: the word in a sentence without a number is text", goals("Gold Ore holen"), "")
    check("goal: not inside a word (Goldshire 5)", goals("Goldshire 5"), "")
    check("goal: German word", ns.Locales.deDE.TASK_WORDS_LEVEL, "stufe")
    check("items: Blizzard's test gear is left out", ns.ItemNames:find("Test Gear", 1, true), nil)
    check("items: a real item with Test in its name stays", ns.ItemNames:find("High Test Eternium Fishing Line", 1, true) ~= nil, true)
    ns.TaskUI.OpenAdd(list)
    p.edit:SetText("Level 50")
    p.edit:GetScript("OnTextChanged")(p.edit, true)
    check("goal: first suggestion", p.results[1].goal, "level")
    p.edit:GetScript("OnArrowPressed")(p.edit, "DOWN")
    enter(p.edit)
    local lvl = list.entries[#list.entries]
    check("goal: picked, added", lvl.goalKind, "level")
    M.state.level = 47
    local gl = ns.Tasks.Line(lvl)
    check("goal: shows level and count", gl.text .. " " .. gl.cur .. "/" .. gl.max, "Level 50 47/50")
    check("goal: not reached", gl.done, false)
    ns.Tasks.Toggle(lvl)
    check("goal: no ticking by hand", lvl.done, nil)
    M.state.level = 50
    check("goal: reached ticks itself", ns.Tasks.Line(lvl).done, true)
    M.state.level = nil
    local count = #list.entries
    ns.Tasks.AddGoal(list, "level", 55)
    check("goal: again changes the amount", lvl.goal .. " " .. #list.entries, 55 .. " " .. count)
    ns.TaskUI.EntryMenu(UIParent, list, lvl)
    check("goal: menu changes the amount", M.menus[#M.menus].entries[1].text, ns.L.TASK_CHANGE_AMOUNT)
    ns.Tasks.RemoveEntry(list, lvl)
    p.edit:SetText("Level 50")
    p.edit:GetScript("OnTextChanged")(p.edit, true)
    enter(p.edit)
    check("goal: Enter without picking keeps a text", list.entries[#list.entries].text, "Level 50")
    ns.Tasks.RemoveEntry(list, list.entries[#list.entries])
    p.edit:SetText("Gold")
    p.edit:GetScript("OnTextChanged")(p.edit, true)
    p.amount:SetText("250")
    p.edit:GetScript("OnArrowPressed")(p.edit, "DOWN")
    enter(p.edit)
    local boxed = list.entries[#list.entries]
    check("goal: Gold with the amount box", (boxed.goalKind or "") .. (boxed.goal or ""), "money250")
    ns.Tasks.RemoveEntry(list, boxed)
    local hadMoney = M.state.money
    M.state.money = 563 * 10000 + 99
    ns.Tasks.AddGoal(list, "money", 1000)
    local gold = list.entries[#list.entries]
    check("goal: gold counts whole gold", ns.Tasks.Line(gold).cur, 563)
    M.state.money = hadMoney
    ns.Tasks.RemoveEntry(list, gold)
    p.edit:GetScript("OnEscapePressed")(p.edit)
    -- Quests from the tracker's menu: ticked once turned in.
    local turnedIn = {}
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return turnedIn[id] end
    local qrow = questRows()[1]
    qrow:GetScript("OnClick")(qrow, "RightButton")
    local addQuest
    for _, e in ipairs(M.menus[#M.menus].entries) do if e.text == list.name then addQuest = e end end
    check("quest: the menu offers the list", addQuest ~= nil, true)
    addQuest.fn()
    local qe = list.entries[#list.entries]
    check("quest: symbol, title, level", ns.Tasks.Line(qe).text:gsub("|cff%x+", ""):gsub("|r", ""),
        ns.Tasks.QUEST_SYMBOL.progress .. " " .. C_QuestLog.GetTitleForQuestID(qe.questID) .. " (" .. qe.level .. ")")
    count = #list.entries
    addQuest.fn()
    check("quest: not twice", #list.entries, count)
    check("quest: open", ns.Tasks.Line(qe).done, false)
    ns.Tasks.Toggle(qe)
    check("quest: no ticking by hand", qe.done, nil)
    turnedIn[qe.questID] = true
    check("quest: turned in ticks itself", ns.Tasks.Line(qe).done, true)
    check("quest: turned in, no level", ns.Tasks.Line(qe).text:find("(", 1, true), nil)
    ns.TaskUI.EntryMenu(UIParent, list, qe)
    check("quest: no edit in its menu", (function()
        for _, e in ipairs(M.menus[#M.menus].entries) do if e.text == ns.L.TASK_EDIT then return true end end
        return false
    end)(), false)
    C_QuestLog.IsQuestFlaggedCompleted = nil
    ns.Tasks.RemoveEntry(list, qe)
    ns.TaskUI.OpenAdd(list)
    local amountArrow = p.amount:GetScript("OnArrowPressed")
    p.amount:SetText("1")
    amountArrow(p.amount, "UP")
    amountArrow(p.amount, "UP")
    check("amount: arrow up", p.amount:GetText(), "3")
    amountArrow(p.amount, "DOWN")
    check("amount: arrow down", p.amount:GetText(), "2")
    amountArrow(p.amount, "LEFT")
    check("amount: left and right move the cursor only", p.amount:GetText(), "2")
    p.amount.stepUp:GetScript("OnClick")(p.amount.stepUp)
    check("amount: arrow button up", p.amount:GetText(), "3")
    p.amount.stepDown:GetScript("OnClick")(p.amount.stepDown)
    check("amount: arrow button down", p.amount:GetText(), "2")
    p.amount:SetText("1")
    amountArrow(p.amount, "DOWN")
    check("amount: not below one", p.amount:GetText(), "1")
    p.amount:SetText("9999")
    amountArrow(p.amount, "UP")
    check("amount: not above the field's four digits", p.amount:GetText(), "9999")
    p.amount:SetText("")
    amountArrow(p.amount, "UP")
    check("amount: empty counts as one", p.amount:GetText(), "2")
    p.edit:GetScript("OnEscapePressed")(p.edit)
    check("Escape closes", p:IsShown(), false)

    local goal = list.entries[1]
    goal.goal = 20
    ns.TaskUI.OpenAmount(goal)
    p.edit:GetScript("OnArrowPressed")(p.edit, "UP")
    check("change amount: arrow up", p.edit:GetText(), "21")
    p.edit.stepDown:GetScript("OnClick")(p.edit.stepDown)
    p.edit.stepDown:GetScript("OnClick")(p.edit.stepDown)
    check("change amount: arrow button", p.edit:GetText(), "19")
    p.ok:GetScript("OnClick")(p.ok)
    check("change amount: saved with OK", goal.goal, 19)
    check("change amount: OK closes", p:IsShown(), false)
    ns.TaskUI.OpenAmount(goal)
    p.edit:SetText("23")
    enter(p.edit)
    check("change amount: saved with Enter", goal.goal, 23)
    ns.TaskUI.OpenAdd(list)
    p.edit:SetText("From the button")
    p.ok:GetScript("OnClick")(p.ok)
    check("adding: OK adds", list.entries[#list.entries].text, "From the button")
    check("adding: OK leaves the window open", p:IsShown(), true)
    Tasks.RemoveEntry(list, list.entries[#list.entries])
    p.edit:GetScript("OnEscapePressed")(p.edit)
    ns.TaskUI.OpenAdd(list)
    check("adding: no arrows in the name field", p.edit.stepUp:IsShown(), false)
    p.edit:GetScript("OnEscapePressed")(p.edit)

    ns.TaskUI.OpenNewList()
    p.edit:SetText("  ")
    enter(p.edit)
    check("empty list name keeps the window", p:IsShown(), true)
    p.edit:SetText("Second")
    enter(p.edit)
    check("new list made", Tasks.Lists()[2].name, "Second")

    Tasks.RemoveDone(list)
    check("remove finished keeps open ones", list.entries[1].itemID, 14047)
    for _, entry in ipairs(list.entries) do check("nothing finished left", Tasks.Line(entry).done, false) end
    local second = Tasks.Lists()[2]
    ns.TaskUI.OpenAdd(second)
    ns.TaskUI.ListMenu(UIParent, second)
    local deleteEntry
    for _, e in ipairs(M.menus[#M.menus].entries) do
        if e.text == ns.L.TASK_DELETE_LIST then deleteEntry = e end
    end
    local asked = #M.popups
    deleteEntry.fn()
    check("delete list: asks first", #M.popups, asked + 1)
    check("delete list: names the list", M.popups[#M.popups].arg, "Second")
    check("delete list: nothing gone yet", Tasks.Lists()[2], second)
    StaticPopupDialogs[M.popups[#M.popups].which].OnAccept(nil, second)
    check("delete list: gone once confirmed", Tasks.Lists()[2], nil)
    check("delete list: its open window closes", p:IsShown(), false)
    Tasks.RemoveList(list)
    check("lists removed", #Tasks.Lists(), 0)
    M.bags, M.bank = nil, nil
    ns.Tracker.Layout()
end

section("Zone levels")
do
    local Z, grey, green, yellow = ns.ZoneLevels, QuestDifficultyColors.trivial, QuestDifficultyColors.standard, QuestDifficultyColors.difficult
    local function at(level, lo, hi) M.state.level = level; return Z.Color(lo, hi, level) end
    check("zone level: red far below", at(20, 30, 40), QuestDifficultyColors.impossible)
    check("zone level: orange 3 below", at(27, 30, 40), QuestDifficultyColors.verydifficult)
    check("zone level: yellow inside", at(35, 30, 40), yellow)
    check("zone level: yellow 2 under the top", at(38, 30, 40), yellow)
    check("zone level: green 1 under the top", at(39, 30, 40), green)
    check("zone level: green at the top", at(40, 30, 40), green)
    check("zone level: green well above", at(46, 30, 40), green)
    check("zone level: grey far above", at(50, 30, 40), grey)
    check("zone level: Riverglades green at 45", at(45, 35, 45), green)
    M.state.level = 40
    head = CreateFrame("Button")
    head.name, head.count, head.chevron = head:CreateFontString(), head:CreateFontString(), head:CreateTexture()
    head.rule = head:CreateTexture()
    ns.Rows.LayoutZone(head, { kind = "zone", name = "Duskwood", count = 1 }, 200, "Duskwood", function() end)
    check("zone header: range behind, grey at 40", head.name:GetText(), "Duskwood |cff7f7f7f(18-30)|r")
    ns.Rows.LayoutZone(head, { kind = "zone", name = "Molten Core", count = 1 }, 200, "Molten Core", function() end)
    check("zone header: one level for raids", head.name:GetText(), "Molten Core |cffff1919(60)|r")
    ns.Rows.LayoutZone(head, { kind = "zone", name = "Class quests", count = 1 }, 200, "x", function() end)
    check("zone header: unknown stays plain", head.name:GetText(), "Class quests")
    ns.Rows.LayoutZone(head, { kind = "section", name = "Duskwood", count = 1 }, 200, "x", function() end)
    check("section header: no range", head.name:GetText(), "Duskwood")
    M.state.level = nil
    check("level data in every language", ns.ZoneLevelData["Dun Morogh"][2], 10)
end

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
    ForeverQuestLog_OnAddonCompartmentEnter = true, ForeverQuestLog_OnAddonCompartmentLeave = true,
    ForeverQuestLog_Binding = true, BINDING_HEADER_FOREVERQUESTLOG = true }
for name in io.open(ROOT .. "/Bindings.xml"):read("*a"):gmatch('name="([%w_]+)"') do allowed["BINDING_NAME_" .. name] = true end
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
