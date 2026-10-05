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
local grip
for _, f in ipairs(M.frames) do if f.icon and f.icon._texture and f.icon._texture:find("IconResize") then grip = f end end
check("grip shown unlocked", grip and grip._shown, true)
M.state.cursorX, M.state.cursorY = 500, 500
local w0, h0 = S("width"), math.max(S("height"), frame._h)
grip:GetScript("OnMouseDown")(grip)
M.state.cursorX, M.state.cursorY = 560, 400       -- right 60, down 100
grip:GetScript("OnUpdate")(grip, 0.1)
grip:GetScript("OnMouseUp")(grip)
check("anchored left: the grip widens to the right", S("width"), w0 + 60)
check("anchored at the top: dragging down grows", S("height"), h0 + 100)
Settings.SetMany({ point = "TOPRIGHT", x = -8, y = -330, width = 300, height = 500 })
Settings.Set("locked", true)
M.RunTimers()
check("grip hidden locked", grip._shown, false)
ns.Tracker.SnapBelowMinimap()
check("below the minimap", S("y"), 767 - 1080 - 16)
check("right edges in line", S("x"), 1912 - 1920)
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
local row1 = M.QuestLogAddQuest("[21] The Greenwarden")
check("Blizzard's style: font untouched", row1.Text._font[2], 12)
check("Blizzard's background shown", QuestScrollFrame.Background._alpha, 1)
Settings.Set("logStyle", "OWN")
Settings.Set("logTitleSize", 18)
QuestScrollFrame.titleFramePool:ReleaseAll()
local row2 = M.QuestLogAddQuest("[22] Alchemical Hazards")
check("own style: title size", row2.Text._font[2], 18)
check("measured with the new font (font set before the text)", row2.measured, 18)
check("own style: Blizzard's parchment faded", QuestScrollFrame.Background._alpha, 0)
check("objectives styled on acquire", (function()
    local f = QuestScrollFrame.objectiveFramePool:Acquire()
    return f.Text._font[1]
end)(), "Fonts\\ARIALN.TTF")
Settings.Set("logStyle", "TRACKER")
QuestScrollFrame.titleFramePool:ReleaseAll()
local row3 = M.QuestLogAddQuest("[22] Spoils of War")
check("like the tracker: title size", row3.Text._font[2], S("titleSize"))
Settings.Set("logStyle", "BLIZZARD")
QuestScrollFrame.titleFramePool:ReleaseAll()
local row4 = M.QuestLogAddQuest("[24] Digging Through the Ooze")
check("back to Blizzard's: font object again", row4.Text._fontObject, M.fontObjects.GameFontNormalLeft)
check("back to Blizzard's: size", row4.Text._font[2], 12)
check("Blizzard's background back", QuestScrollFrame.Background._alpha, 1)
Settings.Set("logTitleSize", nil)
ns.Window.Open()
check("quest log options page", pcall(ns.Window.ShowPage, "questlog"), true)
ns.Window.Toggle()

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

section("Nothing private, no CVars")
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    check("no CVar storage in " .. f, src:find("SetCVar", 1, true), nil)
end
check("Blizzard's tracker and map: no field written", table.concat(M.violations, ","), "")

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
