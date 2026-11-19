-- Themes (Themes.lua): every theme a whole set of settings, CLASSIC never
-- changed by another. Loaded by run.lua with its helpers.
local M, ns, check, section = ...
local Settings, Themes = ns.Settings, ns.Themes
local S = Settings.Get

section("Themes")
local function snapshot() return ns.Share.Export() end
local function sets() return ns.ThemeSets() end
local profile = ns.ActiveProfile()

-- The player's own setup, the Classic one.
Settings.SetMany({ x = -100, titleSize = 14, borderStyle = "GOLD", titleFont = "Arial Narrow" })
local classic = snapshot()
check("starts classic", Themes.Current(), "CLASSIC")

local registry = _G.ForeverThemes and _G.ForeverThemes.ForeverQuestLog
check("registry: entry", registry and registry.title, "Forever Quest Log")
check("registry: current", registry.Current(), "CLASSIC")
ns.DB().width = 301
registry.Refresh()
M.RunTimers()
check("registry: refresh lays out the stored width", ForeverQuestLogFrame:GetWidth(), 301)
ns.DB().width = nil
registry.Refresh()
M.RunTimers()

-- A theme the first time: the classic setup with the theme's look.
check("registry: switch to wood", registry.Switch("WOOD"), true)
M.RunTimers()
check("registry: reports wood", registry.Current(), "WOOD")
check("wood: keeps the position", S("x"), -100)
check("wood: its border", S("borderSize"), 3)
check("wood: its font", S("titleFont"), "Cinzel")
check("wood: the client's outline", S("titleFlag"), "OUTLINE")
check("wood: same size (no add)", S("titleSize"), 14)
check("wood: its backdrop", S("bgTexture"), "FQL Wood")
check("wood: its bars", S("barTexture"), "FQL Wood")
check("wood: the focus frame too", S("focusTitleFont"), "Cinzel")
check("wood: focus border", S("focusBorderStyle"), "GOLD")
check("wood: classic stored", sets().CLASSIC.x, -100)
check("wood: the live set is not stored twice", sets().WOOD, nil)
check("wood: saved in the profile", ns.DB().theme, "WOOD")
local frame = M.byName["ForeverQuestLogFrame"]
check("wood: backdrop darkened", frame.bg._vertex[1], 0.5)
check("wood: rivets", frame.themeArt.ornaments[4]:IsShown(), true)
check("wood: no solid shadow", frame.themeArt.shadow[1]:IsShown(), false)

-- Changes stay with their theme.
Settings.Set("x", -50)
check("switch to pixel", Themes.Switch("PIXEL"), true)
M.RunTimers()
check("pixel: from classic, not from wood", S("x"), -100)
check("pixel: font larger", S("titleSize"), 18)
check("pixel: no solid shadow (stacked edges)", frame.themeArt.shadow[1]:IsShown(), false)
check("pixel: no ornaments", frame.themeArt.ornaments[1]:IsShown(), false)
check("pixel: two to copy from", #Themes.Stored(), 2)

-- Positions from another theme, and back.
local undo = Themes.CopyPlacement("WOOD")
check("copy: done", undo ~= nil, true)
check("copy: position taken", S("x"), -50)
check("copy: look kept", S("titleFont"), "VT323")
check("copy: undo", Themes.Restore(undo), true)
check("copy: undone", S("x"), -100)

-- Back to classic: everything exactly as it was.
check("back to classic", Themes.Switch("CLASSIC"), true)
M.RunTimers()
check("classic: every setting as before", snapshot(), classic)
check("classic: no art left", frame.themeArt.shadow[1]:IsShown(), false)
check("wood again", Themes.Switch("WOOD"), true)
check("wood again: its own change came back", S("x"), -50)

-- Reset: the theme anew from classic.
check("reset", Themes.Reset(), true)
check("reset: from classic", S("x"), -100)
Themes.Switch("CLASSIC")
check("classic: done lines at 13", S("doneSize"), 13)
check("reset: not classic", select(2, Themes.Reset()), "CLASSIC")

-- Refused.
M.state.combat = true
check("combat", select(2, Themes.Switch("TECH")), "COMBAT")
check("combat: registry too", select(2, registry.Switch("TECH")), "COMBAT")
check("combat: still classic", Themes.Current(), "CLASSIC")
M.state.combat = false
check("unknown", select(2, Themes.Switch("NOPE")), "UNKNOWN")
check("copy from a theme never used", select(2, Themes.CopyPlacement("FROST")), "GONE")

-- Display and body texts: a second, readable font where the theme font is not.
local bodySize = S("objectiveSize")
Themes.Switch("GLASS")
M.RunTimers()
check("glass: display font", S("titleFont"), "Morpheus")
check("glass: display size grows", S("titleSize"), 15)
check("glass: body in the standard font", S("objectiveFont"), "Friz Quadrata")
check("glass: body keeps its size", S("objectiveSize"), bodySize)
check("glass: done lines are body too", S("doneFont"), "Friz Quadrata")
check("glass: focus body too", S("focusObjectiveFont"), "Friz Quadrata")
check("glass: body outlined", S("objectiveFlag"), "OUTLINE")
check("glass: content shaded", frame.themeArt.shade:IsShown(), true)
Themes.Switch("COMIC")
M.RunTimers()
check("comic first time: black paper (the shipped look)", registry.Color(), "BLACK")
-- COMIC_HD inherits firstColor BLACK, a colour it lacks: nothing stored, its own first.
do
    local had = sets().COMIC_HD
    Themes.Switch("COMIC_HD")
    check("comic HD first time: no foreign colour stored", (sets().themeColors or {}).COMIC_HD, nil)
    check("comic HD first time: its own first", registry.Color(), "NOIR")
    Themes.Switch("COMIC")
    sets().COMIC_HD = had
end
registry.SetColor("GREY")
M.RunTimers()
check("comic: display outline, not thick (pixelated)", S("titleFlag"), "OUTLINE")
check("comic: body dark ink, no outline", S("objectiveFlag"), "")
check("comic: dark ink", S("objectiveColor")[1], 0.1)
check("comic: no shade", frame.themeArt.shade:IsShown(), false)
check("comic: header icons in ink", Themes.Spec("COMIC").icons.idle[1] < 0.2, true)
check("wood: header icons as they are", Themes.Spec("WOOD").icons, nil)
Themes.Switch("FROST")
M.RunTimers()
check("frost: display and body with a shadow, no outline", S("titleFlag") .. " " .. S("zoneFlag") .. " "
    .. S("objectiveFlag") .. " " .. S("focusTitleFlag"), "SHADOW SHADOW SHADOW SHADOW")
local frostText = frame:CreateFontString()
ns.Media.ApplyText(frostText, Settings.TextStyle("title"))
check("frost: drawn with a 1 px shadow, no outline", select(3, frostText:GetFont()) .. " "
    .. table.concat(frostText._shadow, ","), " 1,-1")
check("frost: done lines as large as objectives", S("doneSize") .. " " .. S("focusDoneSize"),
    S("objectiveSize") .. " " .. S("focusObjectiveSize"))
check("frost: done lines not Classic's 13", S("doneSize") ~= 13, true)
check("frost: body in Julius too", S("objectiveFont") .. "|" .. S("doneFont") .. "|" .. S("focusObjectiveFont"),
    "Julius Sans One|Julius Sans One|Julius Sans One")
Themes.Switch("COMIC")
M.RunTimers()
sets().FROST = nil -- later tests start Frost afresh
-- Body font = theme font with a size add: done lines still match the objectives.
Themes.SPECS.FROST.fontSizeAdd = 2
Themes.Switch("FROST")
check("frost +2: done as large as objectives", S("doneSize") .. " " .. S("focusDoneSize"),
    S("objectiveSize") .. " " .. S("focusObjectiveSize"))
check("frost +2: objectives raised", S("objectiveSize"), Settings.DEFAULTS.objectiveSize + 2)
Themes.SPECS.FROST.fontSizeAdd = nil
Themes.Switch("COMIC")
M.RunTimers()
sets().FROST = nil
-- Nothing reaches beyond the ring: stacked windows keep Classic's edges.
for id, spec in pairs(Themes.SPECS) do
    local art = spec.art or {}
    if art.ornament then check(id .. ": ornaments inside the ring", (art.ornamentInset or 0) >= 0, true) end
    check(id .. ": ring at most 3 px", ((spec.look or {}).borderSize or 3) <= 3, true)
end
-- Level colours in the task list: darkened on the paper, as they are elsewhere.
local lvl = GetQuestDifficultyColor(UnitLevel("player"))
check("comic: level colour inked", ns.Themes.Ink(lvl).g, lvl.g * 0.55)

-- Theme colours: backdrop and accent, apart from the theme sets.
local stored = snapshot()
local function vertex() return table.concat(frame.bg._vertex, "/", 1, 3) end
local function texture() return frame.bg._texture:match("[^\\]+$") end
check("colour: comic grey as picked", registry.Color(), "GREY")
check("colour: the comic nine", table.concat(registry.Colors(), " "),
    "GREY DARKGREY BLACK WHITE YELLOW BLUE RED GREEN PURPLE")
check("colour: by theme", table.concat(registry.Colors("PIXEL"), " "),
    "NAVY PLUM FOREST BROWN GREY BLACK TEAL PURPLE HANDHELD")
check("colour: none for classic", #registry.Colors("CLASSIC"), 0)
check("colour: classic has none", registry.Color("CLASSIC"), nil)
check("comic colour: grey keeps dark ink", Themes.OnPaper(S("objectiveColor"))[1], 0.1)
check("comic colour: grey keeps ink icons", Themes.Icons().idle[1], 0.12)
check("comic colour: grey paper as before", frame.bg._vertex[1], 0.7)
check("comic colour: grey accent as stored", Themes.Accent(S("headerColor"))[3], 0.1)
check("comic colour: blue", registry.SetColor("BLUE"), true)
M.RunTimers()
check("comic colour: blue paper", frame.bg._vertex[3], 0.86)
check("comic colour: own paper", texture(), "ComicBack.tga")
check("comic colour: yellow accent", Themes.Accent(S("headerColor"))[2], 0.9)
check("comic colour: yellow", registry.SetColor("YELLOW"), true)
M.RunTimers()
check("comic colour: yellow paper", frame.bg._vertex[1], 0.86)
check("comic colour: blue accent", Themes.Accent(S("headerColor"))[3], 0.95)
check("comic colour: the look not stored", snapshot(), stored)
check("comic colour: black", registry.SetColor("BLACK"), true)
M.RunTimers()
check("comic colour: black paper", frame.bg._vertex[1], 0.16)
check("comic colour: black, yellow accent", Themes.Accent(S("headerColor"))[2], 0.9)
check("comic colour: black, objectives light", table.concat(Themes.OnPaper(S("objectiveColor")), ","), "0.9,0.9,0.9")
check("comic colour: black, light icons", Themes.Icons().idle[1] .. "/" .. Themes.Icons().hover[1] .. "/"
    .. Themes.Icons().off[1] .. "/" .. Themes.Icons().on[2], "0.85/1/0.55/0.9")
check("comic colour: black, level colours stay light", ns.Themes.Ink(lvl), lvl)
check("comic colour: white", registry.SetColor("WHITE"), true)
M.RunTimers()
check("comic colour: white paper", frame.bg._vertex[1] .. "/" .. frame.bg._vertex[3], "1/1")
check("comic colour: white, blue accent", Themes.Accent(S("headerColor"))[3], 0.95)
check("comic colour: white keeps dark ink", Themes.OnPaper(S("objectiveColor"))[1], 0.1)
check("comic colour: white keeps ink icons", Themes.Icons().idle[1], 0.12)
check("comic colour: white inks level colours", ns.Themes.Ink(lvl).g, lvl.g * 0.55)
registry.SetColor("YELLOW")
check("colour: unknown", select(2, registry.SetColor("PINK")), "UNKNOWN")
check("colour: another theme's id is unknown", select(2, registry.SetColor("NAVY")), "UNKNOWN")
check("colour: unknown leaves it", registry.Color(), "YELLOW")
M.state.combat = true
check("colour: combat", select(2, registry.SetColor("RED")), "COMBAT")
check("colour: another theme in combat", registry.SetColor("WALNUT", "WOOD"), true)
M.state.combat = false

-- Every other theme: the first colour is the theme as it is; another one
-- draws the grey texture at back / mean, with its accent.
Themes.Switch("WOOD")
M.RunTimers()
check("colour: comic kept away from comic", registry.Color("COMIC"), "YELLOW")
check("colour: wood's own kept", registry.Color(), "WALNUT")
check("colour: walnut on the grey wood", texture(), "WoodBackGrey.tga")
check("colour: walnut back / mean", vertex(), (0.15 / 0.8) .. "/" .. (0.09 / 0.8) .. "/" .. (0.06 / 0.8))
check("colour: walnut keeps the accent", Themes.Accent(S("headerColor")), S("headerColor"))
check("colour: wood text as it is", Themes.OnPaper(S("objectiveColor")), S("objectiveColor"))
check("colour: oak", registry.SetColor("OAK"), true)
M.RunTimers()
check("colour: oak as wood was", texture() .. " " .. vertex(), "WoodBack.tga 0.5/0.5/0.5")
check("colour: wood's look not stored", sets().WOOD, nil)
Themes.Switch("TECH")
M.RunTimers()
check("colour: tech cyan as it was", texture() .. " " .. frame.bg._vertex[1], "TechBack.tga 1")
check("colour: tech accent as stored", Themes.Accent(S("headerColor")), S("headerColor"))
check("colour: tech amber", registry.SetColor("AMBER"), true)
M.RunTimers()
check("colour: amber back / mean", vertex(), math.min(1, 0.10 / 0.705) .. "/" .. (0.07 / 0.705) .. "/" .. (0.02 / 0.705))
check("colour: amber accent", table.concat(Themes.Accent(S("headerColor")), "/"), "1/0.75/0.2")
check("colour: amber header icons", table.concat(Themes.Icons().idle, "/"), "1/0.75/0.2")
registry.SetColor("CYAN")
M.RunTimers()
check("colour: cyan header icons in the title's colour", table.concat(Themes.Icons().idle, "/"), "0.25/0.88/0.94")
registry.SetColor("AMBER")
M.RunTimers()
-- Every icon accent readable on its backdrop (back, else the black header):
-- at least 3:1, the contrast WCAG asks of icons.
local function luminance(c)
    local function lin(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
end
for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
    for _, c in ipairs(id ~= "CLASSIC" and id ~= "COMIC" and LibForeverThemes.COLORS[id] or {}) do
        local a = c.accent or c.ornament
        if a then
            local ratio = (luminance(a) + 0.05) / (luminance(c.back or { 0, 0, 0 }) + 0.05)
            check(id .. " " .. c.id .. ": icon accent readable", ratio >= 3, true)
        end
    end
end
check("colour: alpha as the theme's", frame.bg._vertex[4], S("bgAlpha") / 100)
Settings.Set("bgTexture", "FQL Wood")
M.RunTimers()
check("colour: only on the theme's own backdrop", texture() .. " " .. frame.bg._vertex[1], "WoodBack.tga 0.5")
Settings.Set("bgTexture", "FQL Tech")
registry.SetColor("CYAN")
-- Every theme's first colour draws as before. The sets made here are
-- dropped again (later tests start themes afresh).
local made, picked = {}, registry.Color("COMIC")
for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
    if id ~= "CLASSIC" then
        made[id] = sets()[id] == nil and id ~= Themes.Current()
        Themes.Switch(id)
        registry.SetColor(registry.Colors()[1])
        M.RunTimers()
        local back = Themes.Spec(id).look.bgTexture
        if Themes.Spec(id).art.tile then
            -- HD: no theme before it; each colour its own file, drawn white at the set's alpha.
            for _, c in ipairs(LibForeverThemes.COLORS[id]) do
                registry.SetColor(c.id)
                M.RunTimers()
                check(id .. " " .. c.id .. ": its own HD file, white", texture() .. " " .. table.concat(frame.bg._vertex, "/"),
                    c.texture .. " 1/1/1/" .. S("bgAlpha") / 100)
            end
        else
            check(id .. ": first colour as before", ns.Media.Path("background", back):match("[^\\]+$") == texture()
                and frame.bg._vertex[1] == ns.Media.Tint(back), true)
        end
    end
end
registry.SetColor(picked, "COMIC")
Themes.Switch("TECH")
for id in pairs(made) do if made[id] then sets()[id] = nil end end

-- The options' colour row: the current theme's colours, none under Classic.
local colorRow
for _, row in ipairs(ns.Window.PAGES[1].rows()) do
    if row.label == "OPT_THEME_COLOR" then colorRow = row end
end
Themes.Switch("PIXEL")
check("menu: pixel's colours", colorRow.visible() and #colorRow.choices(), 9)
check("menu: their names", colorRow.choices()[2].label, "Plum")
check("menu: current checked", colorRow.get(), "PIXEL:NAVY")
colorRow.set("PIXEL:TEAL")
check("menu: sets", registry.Color("PIXEL"), "TEAL")
registry.SetColor("NAVY")
-- HD is a colour of its base: one set of settings for both.
local function clone(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = clone(v) end
    return c
end
local function themeChoice()
    for _, row in ipairs(ns.Window.PAGES[1].rows()) do
        if row.label == "OPT_THEME_CHOICE" then return row end
    end
end
check("hd: not in the theme menu", (function()
    for _, c in ipairs(themeChoice().choices()) do if c.value:find("_HD$") then return c.value end end
end)(), nil)
Themes.Switch("WOOD")
local woodColors = #LibForeverThemes.Colors("WOOD")
check("hd: wood's colours, then HD", #colorRow.choices() .. " " .. colorRow.choices()[woodColors + 1].label,
    #LibForeverThemes.Colors("WOOD") + #LibForeverThemes.Colors("WOOD_HD") .. " HD " .. ns.L.THEME_COLOR_WOOD_HD_EBONY)
ns.DB().width = 222
colorRow.set("WOOD_HD:EBONY")
check("wood -> wood hd: settings kept", ns.DB().width, 222)
check("wood -> wood hd: theme and colour", Themes.Current() .. " " .. registry.Color(), "WOOD_HD EBONY")
check("wood hd: menus show base and HD colour", themeChoice().get() .. " " .. colorRow.get(), "WOOD WOOD_HD:EBONY")
check("wood hd: no own set stored", sets().WOOD_HD, nil)
themeChoice().set("WOOD")
check("wood hd: choosing wood in the theme menu keeps HD", Themes.Current(), "WOOD_HD")
Themes.Switch("PIXEL")
check("wood hd: stored under wood", sets().WOOD.width, 222)
check("copy from: wood listed, no HD", table.concat(Themes.Stored(), " "):find("_HD") == nil
    and table.concat(Themes.Stored(), " "):find("WOOD") ~= nil, true)
Themes.Switch("WOOD")
check("pixel -> wood: the shared set", ns.DB().width, 222)
-- Sets kept apart before LibForeverThemes 9, merged once: a customised HD set wins.
Themes.Switch("WOOD_HD")
Themes.Reset()
local plainHD = clone(ns.DB())
Themes.Switch("PIXEL")
sets().WOOD_HD = clone(plainHD)
sets().WOOD.width, sets().WOOD.theme = 210, "WOOD"
sets().hdMerged = nil
Themes.Upgrade()
check("merge: plain HD set, wood's stays", sets().WOOD.width, 210)
check("merge: HD set gone", sets().WOOD_HD, nil)
sets().WOOD_HD = clone(plainHD)
sets().WOOD_HD.width = 333
sets().hdMerged = nil
Themes.Upgrade()
check("merge: customised HD set wins", sets().WOOD.width .. " " .. sets().WOOD.theme, "333 WOOD")
-- On the HD theme itself: its live settings win when customised, else wood's.
local function onHD(width)
    Themes.Switch("WOOD")
    ns.DB().theme = "WOOD_HD"
    for k in pairs(ns.DB()) do if k ~= "theme" then ns.DB()[k] = nil end end
    for k, v in pairs(clone(plainHD)) do if k ~= "theme" then ns.DB()[k] = v end end
    ns.DB().width = width
    sets().WOOD = clone(plainHD)
    sets().WOOD.width, sets().WOOD.theme = 199, "WOOD"
    sets().hdMerged = nil
    Themes.Upgrade()
    return S("width") .. " " .. Themes.Current() .. " " .. tostring(sets().WOOD)
end
check("merge: on customised HD, it stays live", onHD(244), "244 WOOD_HD nil")
check("merge: on plain HD, wood's set goes live", onHD(nil), "199 WOOD_HD nil")
-- A profile made active mid-session is merged at once, as at login.
do
    local home = ns.ActiveProfile()
    Themes.Switch("PIXEL")
    ns.SwitchProfile("HD merge")
    sets().WOOD = clone(plainHD)
    sets().WOOD.width, sets().WOOD.theme = 211, "WOOD"
    sets().WOOD_HD = clone(plainHD)
    sets().WOOD_HD.width = 311
    sets().hdMerged = nil
    ns.SwitchProfile(home)
    ns.SwitchProfile("HD merge")
    check("merge on profile switch: customised HD wins at once", sets().WOOD.width .. " " .. tostring(sets().WOOD_HD), "311 nil")
    ns.SwitchProfile(home)
    ns.DeleteProfile("HD merge")
end
Themes.Switch("PIXEL")
sets().WOOD = nil
Themes.Switch("CLASSIC")
check("menu: none under classic", colorRow.visible(), false)
Themes.Switch("COMIC")
M.RunTimers()
check("comic colour: back to comic", frame.bg._vertex[2], 0.76)
check("comic colour: grey again", registry.SetColor("GREY"), true)
M.RunTimers()
check("comic colour: grey paper restored", frame.bg._vertex[1], 0.7)
check("comic colour: grey accent restored", Themes.Accent(S("headerColor"))[1], 1)
sets().themeColors.COMIC = "PINK"
check("colour: unknown stored is the first", registry.Color(), "GREY")
sets().themeColors = nil
sets().comicColor = "RED"
check("colour: comicColor moves in", registry.Color() .. " " .. tostring(sets().comicColor), "RED nil")
sets().themeColors = nil

Themes.Switch("WOOD")
check("wood: body in Friz", S("objectiveFont"), "Friz Quadrata")
check("wood: level colour as it is", ns.Themes.Ink(lvl), lvl)
check("tech: no corner pieces", Themes.SPECS.TECH.art.ornament, nil)
Themes.Switch("CLASSIC")
check("classic after the body fonts", snapshot(), classic)

-- Swiss, Console, Pitwall: display face for display texts only, the text
-- face for the body, no size growth.
local function ringColor() return table.concat(ns.Border.Pieces(frame)[1]._vertex, "/", 1, 3) end
local function wedge() return frame.themeArt.wedge end
local themeRow
for _, row in ipairs(ns.Window.PAGES[1].rows()) do
    if row.label == "OPT_THEME_CHOICE" then themeRow = row end
end
local listed = {}
for _, c in ipairs(themeRow.choices()) do listed[#listed + 1] = c.value end
check("new: in the options' list, appended", table.concat(listed, " ", 10, 12), "SWISS CONSOLE PITWALL")
check("framed: in the options' list, appended", table.concat(listed, " ", 13, 14), "AZEROTH GOBLIN")
check("HD: not in the options' list (colours of their base)", listed[15], nil)
-- Every theme and colour the menus offer has its name in every language.
for code, strings in pairs(ns.Locales) do
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
        check(code .. ": THEME_" .. id, strings["THEME_" .. id] ~= nil, true)
        for _, c in ipairs(LibForeverThemes.Colors(id)) do
            check(code .. ": THEME_COLOR_" .. id .. "_" .. c, strings["THEME_COLOR_" .. id .. "_" .. c] ~= nil, true)
        end
    end
end
check("new: their names", themeRow.choices()[10].label, "Swiss Clean")
local titleSize = S("titleSize")
Themes.Switch("SWISS")
M.RunTimers()
check("swiss: display face", S("titleFont") .. "/" .. S("zoneFont") .. "/" .. S("headerFont"),
    "Inter Tight Bold/Inter Tight Bold/Inter Tight Bold")
check("swiss: body face", S("objectiveFont") .. "/" .. S("doneFont"), "Inter Tight/Inter Tight")
check("swiss: no size growth", S("titleSize") .. "/" .. S("objectiveSize"), titleSize .. "/" .. bodySize)
check("swiss: its backdrop", texture() .. " " .. frame.bg._vertex[1], "SwissBack.tga 1")
check("swiss: hairline ring", ringColor(), "0.165/0.165/0.165")
check("swiss: white rule on top", frame.themeArt.band:IsShown() and frame.themeArt.band:GetHeight(), 3)
check("swiss: no ornaments", frame.themeArt.ornaments[1]:IsShown() or wedge():IsShown(), false)
check("swiss: red accent", table.concat(Themes.Accent(S("headerColor")), "/"), "1/0.176/0.125")
check("swiss: colours", table.concat(registry.Colors(), " "), "RED BLUE YELLOW WHITE")
registry.SetColor("BLUE")
M.RunTimers()
check("swiss blue: accent", Themes.Accent(S("headerColor"))[3], 1)
check("swiss blue: backdrop stays", texture() .. " " .. frame.bg._vertex[1], "SwissBack.tga 1")
check("swiss blue: ring stays", ringColor(), "0.165/0.165/0.165")
registry.SetColor("RED")
Themes.Switch("CONSOLE")
M.RunTimers()
check("console: fonts", S("titleFont") .. "/" .. S("objectiveFont"), "IBM Plex Sans Condensed Bold/IBM Plex Mono")
check("console: mint ring", ringColor(), "0.306/0.929/0.69")
check("console: no band", frame.themeArt.band:IsShown(), false)
check("console: colours", table.concat(registry.Colors(), " "), "MINT AMBER PHOSPHOR VIOLET")
registry.SetColor("AMBER")
M.RunTimers()
check("console amber: the ring follows", ringColor(), "1/0.69/0")
check("console amber: accent", table.concat(Themes.Accent(S("headerColor")), "/"), "1/0.69/0")
check("console amber: backdrop stays", texture() .. " " .. frame.bg._vertex[1], "ConsoleBack.tga 1")
check("console amber: not stored", S("borderColor")[1], 0.306)
registry.SetColor("MINT")
M.RunTimers()
check("console mint: ring as stored", ringColor(), "0.306/0.929/0.69")
Themes.Switch("PITWALL")
M.RunTimers()
check("pitwall: fonts", S("titleFont") .. "/" .. S("objectiveFont"), "Titillium Web Bold Italic/Titillium Web SemiBold")
check("pitwall: carbon hairline", ringColor(), "0.043/0.047/0.055")
check("pitwall: black title strip as high as the header", table.concat(frame.themeArt.band._texColor, "/") .. " " .. frame.themeArt.band:GetHeight(), "0/0/0/1 32")
check("pitwall: red wedge", wedge():IsShown() and table.concat(wedge()._vertex, "/", 1, 3), "0.882/0.024/0")
local headerTitle
for _, fs in ipairs(M.fontStrings) do
    local point, rel = fs:GetPoint()
    if fs:GetText() == ns.L.HEADER_QUESTS and point == "LEFT" and rel == nil then headerTitle = fs end
end
check("pitwall: wedge as high as the band, flush top left", wedge():GetHeight() .. "x" .. wedge():GetWidth() .. " "
    .. table.concat(wedge()._points.TOPLEFT, "/", 3), "32x32 0/0")
check("pitwall: no corner ornaments", frame.themeArt.ornaments[1]:IsShown(), false)
-- The family's rule: the wedge's right edge at mid-height (0.8 of 32 = 26), 8 past it.
check("pitwall: title (locked) or grip 8 past the wedge's middle", select(4, headerTitle:GetPoint()), S("locked") and 26 + 8 or 26 + 8 + 18)
check("pitwall: wedge the texture's slanted part", wedge()._texCoord and wedge()._texCoord[2], 0.53)
check("pitwall: hairline under the band", frame.themeArt.rule:IsShown() and table.concat(frame.themeArt.rule._texColor, "/")
    .. " " .. frame.themeArt.rule._points.TOPLEFT[2], "0.137/0.149/0.173/1 BOTTOMLEFT")
check("pitwall: content on the backdrop edge to edge, no inset shade", frame.themeArt.shade:IsShown(), false)
local function vertex3(t) return table.concat(t._vertex, "/", 1, 3) end
-- The tracker's header button showing icon (its header is the frame's child).
local function headerIcon(icon)
    for _, f in ipairs(M.frames) do
        local p = f._parent
        if f.icon and f.icon._texture == ns.Media.Icon(icon) and p and p._parent == frame then return f.icon end
    end
end
check("pitwall: header icons in the wedge's red", vertex3(headerIcon("Gear")) .. " " .. vertex3(headerIcon("Plus")), "0.882/0.024/0 0.882/0.024/0")
check("pitwall: inactive icon the red darker", vertex3(headerIcon("Zones")), S("groupByZone") and "0.882/0.024/0" or "0.5292/0.0144/0")
check("pitwall: hover the red lighter", table.concat(Themes.Icons().hover, "/"), "0.941/0.512/0.5")
check("pitwall: zone headers white", table.concat(S("zoneColor"), "/"), "0.949/0.953/0.961")
check("pitwall: colours", table.concat(registry.Colors(), " "), "RED ORANGE TEAL SILVER")
registry.SetColor("TEAL")
M.RunTimers()
check("pitwall teal: wedge", table.concat(wedge()._vertex, "/", 1, 3), "0/0.631/0.612")
check("pitwall teal: header as stored", Themes.Accent(S("headerColor")), S("headerColor"))
check("pitwall teal: header icons follow the wedge", vertex3(headerIcon("Gear")), "0/0.631/0.612")
check("pitwall teal: backdrop stays", texture() .. " " .. frame.bg._vertex[1], "SwissBack.tga 1")
registry.SetColor("RED")
-- Swiss and Pitwall share one black with every Forever addon: the flat
-- backdrop untinted, opaque.
for _, id in ipairs({ "SWISS", "PITWALL" }) do
    Themes.Switch(id)
    M.RunTimers()
    check(id .. ": the shared black", texture() .. " " .. table.concat(frame.bg._vertex, "/") .. " " .. S("bgMode"),
        "SwissBack.tga 1/1/1/1 TEXTURE")
end
-- Pixel's handheld: four greens, the rim too.
Themes.Switch("PIXEL")
check("pixel: handheld appended", registry.Colors()[9], "HANDHELD")
registry.SetColor("HANDHELD")
M.RunTimers()
check("handheld: grey pixel at back / mean", texture() .. " " .. vertex(),
    "PixelBackGrey.tga " .. (0.059 / 0.8) .. "/" .. (0.122 / 0.8) .. "/" .. (0.059 / 0.8))
check("handheld: green rim", ringColor(), "0.784/0.941/0.439")
check("handheld: green accent", table.concat(Themes.Accent(S("headerColor")), "/", 1, 3), "0.784/0.941/0.439")
registry.SetColor("NAVY")
M.RunTimers()
check("navy: rim as stored", ringColor(), "1/0.95/0.91")
-- Rings: the same per theme and colour in every Forever addon (this table
-- in each of them); only Console's colours and Handheld tint the ring.
local RINGS = {
    WOOD = "GOLD", TECH = "0.25/0.88/0.94/0.9", PARCHMENT = "0.29/0.2/0.12/1", RUNESTONE = "0.1/0.1/0.12/1",
    GLASS = "0.07/0.06/0.05/1", COMIC = "0.07/0.07/0.07/1", FROST = "0.86/0.96/1/0.8", PIXEL = "1/0.95/0.91/1",
    SWISS = "0.165/0.165/0.165/1", CONSOLE = "0.306/0.929/0.69/1", PITWALL = "0.043/0.047/0.055/1",
    AZEROTH = "0.79/0.635/0.29/1", GOBLIN = "0.23/0.11/0.05/1",
}
local RING_OVERRIDES = { CONSOLE = { AMBER = "1/0.69/0/1", PHOSPHOR = "0.224/1/0.078/1", VIOLET = "0.627/0.471/1/1" },
    PIXEL = { HANDHELD = "0.784/0.941/0.439/1" } }
local function drawnRing(owner, style)
    local piece = ns.Border.Pieces(owner)[1]
    if style == "GOLD" then return "GOLD" end
    return piece and piece:IsShown() and table.concat(piece._vertex, "/") or "none"
end
local windows, had = { frame }, {}
for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do had[id] = sets()[id] ~= nil end
for _, win in pairs(ns.Notes.windows) do windows[#windows + 1] = win end
check("rings: a note window drawn too", #windows > 1, true)
for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
    if id ~= "CLASSIC" then
        Themes.Switch(id)
        local before = registry.Color()
        for _, colour in ipairs(registry.Colors()) do
            registry.SetColor(colour)
            M.RunTimers()
            local want = (RING_OVERRIDES[id] or {})[colour] or RINGS[LibForeverThemes.BaseTheme(id)]
            for i, win in ipairs(windows) do
                if i > 1 then ns.Notes.LayoutWindow(win) end
                check(id .. " " .. colour .. ": ring of window " .. i, drawnRing(win, S("borderStyle")), want)
            end
            -- The focus frame draws only with a quest in focus: its ring from
            -- the same expression as Focus.lua's.
            local focusRing = S("focusBorderStyle") == "GOLD" and "GOLD"
                or table.concat(Themes.Rim(S("focusBorderColor")), "/")
            check(id .. " " .. colour .. ": ring of the focus frame", focusRing, want)
        end
        registry.SetColor(before)
    end
end
-- The to-do title starts past Pitwall's wedge, where the tracker's does.
Themes.Switch("PITWALL")
M.RunTimers()
ns.Notes.LayoutWindow(windows[2])
local note = windows[2]
check("pitwall: note wedge as high as its title band", note.themeArt.wedge:GetHeight() .. " " .. note.themeArt.band:GetHeight()
    .. " " .. note.titleH, note.titleH .. " " .. note.titleH .. " " .. note.titleH)
check("pitwall: note title 8 past the wedge's middle", note.name._points.LEFT[3] + 8, math.floor(0.8 * note.titleH + 0.5) + 8)
check("pitwall: note title in the text colour", table.concat(note.name._textColor or {}, "/", 1, 3), "0.949/0.953/0.961")
check("pitwall: note icons in the wedge's colour, a plain X", vertex3(note.close.icon) .. " " .. vertex3(note.gear.icon) .. " "
    .. vertex3(note.add.icon) .. " " .. note.close.icon._texture:match("[^\\]+$"),
    "0.882/0.024/0 0.882/0.024/0 0.882/0.024/0 IconClose.tga")
check("pitwall: note grip too", vertex3(note.grip.icon), "0.882/0.024/0")
registry.SetColor("ORANGE")
M.RunTimers()
ns.Notes.LayoutWindow(note)  -- as the rings above: Notes.Layout redraws only undocked lists
check("pitwall orange: note icons follow", vertex3(note.gear.icon) .. " " .. vertex3(note.grip.icon), "1/0.541/0 1/0.541/0")
registry.SetColor("RED")
M.RunTimers()
check("pitwall: note shade none, so no uneven margin", note.themeArt.shade:IsShown(), false)
check("pitwall: air between the title band and the first entry", -note.scroll._points.TOPLEFT[4] - note.titleH, 6)
Themes.Switch("CLASSIC")
M.RunTimers()
for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
    if id ~= "CLASSIC" and not had[id] then sets()[id] = nil end
end
for _, id in ipairs({ "SWISS", "CONSOLE", "PITWALL", "PIXEL" }) do sets()[id] = nil end
ns.Notes.LayoutWindow(windows[2])
check("classic: note title at the edge", windows[2].name._points.LEFT[3], 0)
check("classic: note X and grip as before", windows[2].close.icon._texture .. " " .. vertex3(windows[2].grip.icon),
    "Interface\\Buttons\\UI-StopButton 0.31/0.76/0.97")
check("classic: no wedge, no rule", windows[2].themeArt.wedge:IsShown() or windows[2].themeArt.rule:IsShown(), false)
check("classic after the new themes", snapshot(), classic)
check("classic: no band left", frame.themeArt.band:IsShown(), false)

-- Latin fonts only on Latin clients.
M.locale = "koKR"
Themes.Switch("FROST")
check("koKR: own font kept", S("titleFont"), "Arial Narrow")
check("koKR: theme look still", S("bgTexture"), "FQL Frost")
Themes.Switch("CLASSIC")
M.locale = "enUS"

-- Reset and import never take Classic's place.
Themes.Switch("WOOD")
Settings.ResetProfile()
check("profile reset: theme stays", Themes.Current(), "WOOD")
Themes.Switch("CLASSIC")
check("profile reset: classic untouched", snapshot(), classic)

-- The sets follow the profile.
Themes.Switch("WOOD")
check("save as", ns.SwitchProfile("Theme copy"), true)
check("save as: sets copied", ForeverQuestLogProfiles.themeSets["Theme copy"].CLASSIC.x, -100)
ns.SwitchProfile(profile)
check("delete", ns.DeleteProfile("Theme copy"), true)
check("delete: sets gone", ForeverQuestLogProfiles.themeSets["Theme copy"], nil)

-- A theme stored under an older revision is made anew; Classic stays.
Settings.Set("bgAlpha", 30)
Themes.Switch("TECH")
Themes.Switch("WOOD")
sets().revision = 0
Themes.Upgrade()
check("upgrade: the theme in use made anew", S("bgAlpha"), 100)
check("upgrade: from classic", S("x"), -100)
check("upgrade: stale set dropped", sets().TECH, nil)
check("upgrade: classic kept", sets().CLASSIC.x, -100)
check("upgrade: revision noted", sets().revision .. " " .. sets().seedRevision, "11 " .. LibForeverThemes.SEED_REVISION)
-- A set stored by the release before (revision 11, no seedRevision) counts as
-- current: logging in keeps it as it is.
Themes.Switch("TECH")
Settings.Set("bgAlpha", 55)
Themes.Switch("WOOD")
sets().revision, sets().seedRevision = 11, nil
Themes.Upgrade()
Themes.Switch("TECH")
check("upgrade: a stored set of the last release survives login", S("bgAlpha"), 55)
Themes.Switch("WOOD")
Settings.Set("bgAlpha", 40)
Themes.Upgrade()
check("upgrade: once only", S("bgAlpha"), 40)
-- A Frost set stored before the done fix (done at Classic's 13) is rebuilt.
Themes.Switch("FROST")
Settings.Set("doneSize", 13)
sets().revision = 0
Themes.Upgrade()
check("upgrade: frost done lines as large as objectives", S("doneSize") .. " " .. S("focusDoneSize"),
    S("objectiveSize") .. " " .. S("focusObjectiveSize"))
Themes.Switch("CLASSIC")
check("classic after all of it", snapshot(), classic)

-- A font the client refuses at first use: the client's font meanwhile,
-- ours again shortly.
local fs = UIParent:CreateFontString()
local setFont, refusals = fs.SetFont, 1
local cinzel = ns.Media.FontPath("Cinzel")
fs.SetFont = function(self, path, ...)
    if refusals > 0 and path == cinzel then refusals = refusals - 1; return false end
    return setFont(self, path, ...)
end
local refreshAll, relaid = ns.Tracker.RefreshAll, 0
ns.Tracker.RefreshAll = function() relaid = relaid + 1 end
ns.Media.ApplyText(fs, { font = "Cinzel", size = 12, flag = "OUTLINE", color = { 1, 1, 1 } })
check("refused: the client's font meanwhile", (fs:GetFont()), ns.Media.DEFAULT.font)
check("refused: no layout yet", relaid, 0)
M.RunTimers()
check("tried again: taken", (fs:GetFont()), cinzel)
-- Measured with the client's font so far (a wide font broke titles over the next line).
check("taken: tracker and focus laid out anew", relaid > 0, true)
ns.Tracker.RefreshAll = refreshAll
check("shipped fonts are listed", cinzel:find("Libs\\LibForeverThemes\\Media\\Fonts\\Cinzel", 1, true) ~= nil, true)

-- "Apply to all Forever addons": only with another addon listed; puts it on
-- this theme and colour, skips it when it lacks the theme.
local allRow
for _, row in ipairs(ns.Window.PAGES[1].rows()) do
    if row.buttons and row.buttons[1].label == "OPT_THEME_ALL" then allRow = row end
end
check("apply all: hidden alone", allRow.visible(), false)
local other, known = { theme = "CLASSIC" }, { CLASSIC = {}, PIXEL = { "NAVY", "TEAL" } }
_G.ForeverThemes.FakeOther = {
    title = "Fake", Current = function() return other.theme end,
    Switch = function(id)
        if not known[id] then return nil, "UNKNOWN" end
        other.theme = id
        return true
    end,
    Colors = function(theme) return known[theme] end,
    SetColor = function(id) other.color = id; return true end,
}
check("apply all: shown with another", allRow.visible(), true)
Themes.Switch("PIXEL")
registry.SetColor("TEAL")
M.chat = {}
allRow.buttons[1].onClick()
check("apply all: theme and colour", other.theme .. " " .. tostring(other.color), "PIXEL TEAL")
check("apply all: says how many", (M.chat[1] or ""):find("1 other", 1, true) ~= nil, true)
Themes.Switch("WOOD")
check("apply all: unknown theme skipped", Themes.ApplyToAll() .. " " .. other.theme, "0 PIXEL")
_G.ForeverThemes.FakeOther = nil
registry.SetColor("NAVY", "PIXEL")
Themes.Switch("CLASSIC")

-- Following the hub "Forever Themes": the pickers greyed with the current
-- theme still shown, a line and a button to the hub, no "Apply to all".
-- Own theme or no hub: as before. The flag is read again on every refresh.
local Lib = LibForeverThemes
local hubFollows, hubOpened = true, 0
_G.ForeverThemes.FakeOther = { title = "Fake", Current = function() return "CLASSIC" end, Switch = function() return true end }
Lib.SetHub({
    Follows = function(folder) return folder == "ForeverQuestLog" and hubFollows end,
    OpenOptions = function() hubOpened = hubOpened + 1 end,
})
Themes.Switch("PIXEL")
ns.Window.Open("general")
local page = M.byName["ForeverQuestLogPagegeneral"]
local function built(label)
    for i, opt in ipairs(ns.Window.PAGES[1].rows()) do
        local name = opt.label or (opt.buttons and opt.buttons[1].label)
        if type(name) == "function" then name = name() end   -- the library's hub texts
        if name == label then return page.allRows[i] end
    end
end
local function usable(label) return built(label).button:IsEnabled() end
check("hub follow: theme greyed", usable("OPT_THEME_CHOICE"), false)
check("hub follow: still shows the theme", built("OPT_THEME_CHOICE").button.text:GetText(), "Pixel")
check("hub follow: colour greyed", usable("OPT_THEME_COLOR"), false)
check("hub follow: the line", built(Lib.Text("HUB_FOLLOWS")):IsShown(), true)
check("hub follow: the line's text", built(Lib.Text("HUB_FOLLOWS")).text:GetText(), "Follows Forever Themes")
ns.Locale.Set("deDE")   -- the addon's own language, not the (English) client's
page = M.byName["ForeverQuestLogPagegeneral"]   -- a new language builds a new window
check("german addon, english client: the line", built("Folgt Forever Themes").text:GetText(), "Folgt Forever Themes")
ns.Locale.Set("AUTO")
page = M.byName["ForeverQuestLogPagegeneral"]
check("hub follow: the button", built(Lib.Text("HUB_OPEN")):IsShown(), true)
check("hub follow: no apply to all", built("OPT_THEME_ALL"):IsShown(), false)
built(Lib.Text("HUB_OPEN")).buttons[1]:GetScript("OnClick")(built(Lib.Text("HUB_OPEN")).buttons[1])
check("hub follow: button opens the hub", hubOpened, 1)
-- A profile switch, reset or import replaced the theme: the hub puts its own
-- back.
local synced = 0
Lib.Hub().Sync = function() synced = synced + 1 end
local text = ns.Share.Export()
ns.Share.Import(text)
Settings.ResetProfile()
ns.SwitchProfile(ns.ActiveProfile())
check("hub: synced after import, reset and profile switch", synced, 3)
Lib.Hub().Sync = nil

hubFollows = false
ns.Window.Refresh()
check("hub own: theme usable", usable("OPT_THEME_CHOICE"), true)
check("hub own: colour usable", usable("OPT_THEME_COLOR"), true)
check("hub own: no line", built(Lib.Text("HUB_FOLLOWS")):IsShown(), false)
check("hub own: no button", built(Lib.Text("HUB_OPEN")):IsShown(), false)
check("hub own: apply to all", built("OPT_THEME_ALL"):IsShown(), true)
check("hub: no download hint", built(Lib.Text("HUB_MISSING")):IsShown(), false)
check("hub: no link button", built(Lib.Text("HUB_LINK")):IsShown(), false)

Lib.SetHub(nil)
hubFollows = true
ns.Window.Refresh()
check("no hub: theme usable", usable("OPT_THEME_CHOICE"), true)
check("no hub: no line", built(Lib.Text("HUB_FOLLOWS")):IsShown(), false)
check("no hub: apply to all", built("OPT_THEME_ALL"):IsShown(), true)
check("no hub: points to Forever Themes", built(Lib.Text("HUB_MISSING")).text:GetText(), "Theme all Forever addons at once: Forever Themes")
M.popups = {}
built(Lib.Text("HUB_LINK")).buttons[1]:GetScript("OnClick")(built(Lib.Text("HUB_LINK")).buttons[1])
check("no hub: link button opens the copy box", M.popups[1] and M.popups[1].which, "LIBFOREVERTHEMES_HUB_LINK")
local linkBox = { SetText = function(self, t) self.text = t end, HighlightText = function() end, SetFocus = function() end }
StaticPopupDialogs.LIBFOREVERTHEMES_HUB_LINK.OnShow({ GetEditBox = function() return linkBox end })
check("no hub: the hub's CurseForge page", linkBox.text, "https://www.curseforge.com/wow/addons/forever-themes")
ns.Window.Toggle()
_G.ForeverThemes.FakeOther = nil
Themes.Switch("CLASSIC")

-- The shipped look: a theme picked the first time is the author's setup of
-- it (his saved settings without positions, sizes and behaviour).
local SHIPPED = {
    SWISS = { barTexture = "FQL Swiss", bgTexture = "FQL Swiss", borderColor = { 0.165, 0.165, 0.165, 1 },
        borderStyle = "FLAT", cornerRadius = 0, doneFont = "Inter Tight", doneSize = 11, focusBgMode = "TEXTURE",
        focusBgTexture = "FQL Swiss", focusObjectiveFont = "Inter Tight", focusTitleFont = "Inter Tight Bold",
        headerColor = { 1, 0.176, 0.125 }, headerFont = "Inter Tight Bold", headerLine = false, headerShine = false,
        objectiveColor = { 0.949, 0.949, 0.949 }, objectiveDoneColor = { 0.549, 0.549, 0.549 },
        objectiveFlag = "OUTLINE", objectiveFont = "Inter Tight", shadowEnabled = false,
        titleFont = "Inter Tight Bold", zoneColor = { 0.549, 0.549, 0.549 }, zoneFont = "Inter Tight Bold" },
    PITWALL = { barTexture = "FQL Pitwall", bgTexture = "FQL Swiss", borderColor = { 0.043, 0.047, 0.055, 1 },
        doneColor = { 0.133, 0.773, 0.369 }, doneFont = "Titillium Web SemiBold", doneSize = 11,
        focusDoneColor = { 0.133, 0.773, 0.369 }, focusTitleFont = "Titillium Web Bold Italic",
        headerColor = { 0.949, 0.953, 0.961 }, headerFont = "Titillium Web Bold Italic", headerLine = false,
        objectiveDoneColor = { 0.604, 0.631, 0.671 }, objectiveFont = "Titillium Web SemiBold",
        shadowEnabled = false, titleFont = "Titillium Web Bold Italic", zoneFont = "Titillium Web Bold Italic" },
}
local SHIPPED_COLOR = { SWISS = "RED", PITWALL = "RED", COMIC = "BLACK" }
for id, look in pairs(SHIPPED) do
    sets()[id], sets().themeColors = nil, nil
    Themes.Switch(id)
    for k, v in pairs(look) do check(id .. " shipped: " .. k, Settings.SameValue(S(k), v), true) end
    check(id .. " shipped: colour", registry.Color(), SHIPPED_COLOR[id])
    Themes.Switch("CLASSIC")
end
check("shipped: classic untouched", snapshot(), classic)

-- Someone already on a theme keeps it as stored: no new colour, no new look.
sets().themeColors = nil
Themes.Switch("COMIC")
local mine = ns.Share.Export()
Themes.Switch("CLASSIC")
sets().themeColors = nil
Themes.Upgrade()
Themes.Switch("COMIC")
check("stored comic: set unchanged", ns.Share.Export(), mine)
check("stored comic: colour stays the first", registry.Color(), "GREY")
Themes.Switch("CLASSIC")


-- The framed themes (LibForeverThemes 10): a material frame outside the ring,
-- a textured title band.
local function file(tex) return tex._texture and tex._texture:match("[^\\]+$") end
local art = frame.themeArt
Themes.Switch("AZEROTH")
M.RunTimers()
check("azeroth: fonts", S("titleFont") .. "/" .. S("objectiveFont"), "Cinzel/Alegreya")
check("azeroth: light parchment from its own file", texture(), "AzerothParchment")
local framed = 0
for _, strip in ipairs(art.frame) do
    if strip:IsShown() and file(strip) == "WoodHDWalnut" then framed = framed + 1 end
end
check("azeroth: walnut frame on four sides", framed, 4)
local top = art.frame[1]._points.TOPLEFT
check("azeroth: frame outside the ring, 7 wide", top[3] == -top[4] and top[4] >= 7, true)
check("azeroth: banner as the title band", art.band:IsShown() and file(art.band), "AzerothBanner")
check("azeroth: banner ends, the right one mirrored", art.ends[1]:IsShown() and art.ends[2]._texCoord[1], 1)
check("azeroth: title past the banner's end", select(4, headerTitle:GetPoint()), S("locked") and 16 or 16 + 18)
check("azeroth: gold corners on the frame", art.ornaments[1]:IsShown() and file(art.ornaments[1]), "Bracket")
check("azeroth: a level in a title in dark ink", table.concat(Themes.TitleInk({ 1, 1, 1 }), "/"), "0.55/0.55/0.55")
Themes.Switch("GOBLIN")
M.RunTimers()
check("goblin: fonts", S("titleFont") .. "/" .. S("objectiveFont"), "Bungee/Rubik Medium")
check("goblin: copper frame", art.frame[1]:IsShown() and file(art.frame[1]), "GoblinCopper")
check("goblin: hazard strip 5 high, repeating", file(art.band) .. " " .. art.band:GetHeight() .. " "
    .. tostring(art.band:GetHorizTile()), "GoblinHazard 5 true")
check("goblin: no banner ends", art.ends[1]:IsShown(), false)
check("goblin: a level in a title as it is (outlined light text)", table.concat(Themes.TitleInk({ 1, 1, 1 }), "/"), "1/1/1")
Themes.Switch("SWISS")
M.RunTimers()
check("swiss after them: no frame, no ends", art.frame[1]:IsShown() or art.ends[1]:IsShown(), false)
check("swiss after them: the band a colour again", art.band:GetHorizTile(), false)
Themes.Switch("CLASSIC")
M.RunTimers()
check("classic after them: no frame", art.frame[1]:IsShown(), false)
