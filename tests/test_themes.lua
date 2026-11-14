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
check("comic: display outline, not thick (pixelated)", S("titleFlag"), "OUTLINE")
check("comic: body dark ink, no outline", S("objectiveFlag"), "")
check("comic: dark ink", S("objectiveColor")[1], 0.1)
check("comic: no shade", frame.themeArt.shade:IsShown(), false)
check("comic: header icons in ink", Themes.Spec("COMIC").icons.idle[1] < 0.2, true)
check("wood: header icons as they are", Themes.Spec("WOOD").icons, nil)
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
check("colour: comic grey by default", registry.Color(), "GREY")
check("colour: the comic nine", table.concat(registry.Colors(), " "),
    "GREY DARKGREY BLACK WHITE YELLOW BLUE RED GREEN PURPLE")
check("colour: by theme", table.concat(registry.Colors("PIXEL"), " "), "NAVY PLUM FOREST BROWN GREY BLACK TEAL PURPLE")
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
check("colour: alpha as the theme's", frame.bg._vertex[4], S("bgAlpha") / 100)
Settings.Set("bgTexture", "FQL Wood")
M.RunTimers()
check("colour: only on the theme's own backdrop", texture() .. " " .. frame.bg._vertex[1], "WoodBack.tga 0.5")
Settings.Set("bgTexture", "FQL Tech")
registry.SetColor("CYAN")
-- Every theme's first colour draws as before. The sets made here are
-- dropped again (later tests start themes afresh).
local made, picked = {}, registry.Color("COMIC")
for _, id in ipairs(Themes.IDS) do
    if id ~= "CLASSIC" then
        made[id] = sets()[id] == nil and id ~= Themes.Current()
        Themes.Switch(id)
        registry.SetColor(registry.Colors()[1])
        M.RunTimers()
        local back = Themes.Spec(id).look.bgTexture
        check(id .. ": first colour as before", ns.Media.Path("background", back):match("[^\\]+$") == texture()
            and frame.bg._vertex[1] == ns.Media.Tint(back), true)
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
check("menu: pixel's colours", colorRow.visible() and #colorRow.choices(), 8)
check("menu: their names", colorRow.choices()[2].label, "Plum")
check("menu: current checked", colorRow.get(), "NAVY")
colorRow.set("TEAL")
check("menu: sets", registry.Color("PIXEL"), "TEAL")
registry.SetColor("NAVY")
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
check("tech: no corner pieces", Themes.SPECS.TECH.art, nil)
check("revision", Themes.REVISION, 4)
Themes.Switch("CLASSIC")
check("classic after the body fonts", snapshot(), classic)

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
check("upgrade: revision noted", sets().revision, Themes.REVISION)
Settings.Set("bgAlpha", 40)
Themes.Upgrade()
check("upgrade: once only", S("bgAlpha"), 40)
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
ns.Media.ApplyText(fs, { font = "Cinzel", size = 12, flag = "OUTLINE", color = { 1, 1, 1 } })
check("refused: the client's font meanwhile", (fs:GetFont()), ns.Media.DEFAULT.font)
M.RunTimers()
check("tried again: taken", (fs:GetFont()), cinzel)
check("shipped fonts are listed", cinzel:find("Media\\Fonts\\Cinzel", 1, true) ~= nil, true)
