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

-- Comic colours: paper and accent, apart from the theme sets.
local stored = snapshot()
check("comic colour: grey by default", registry.ComicColor(), "GREY")
check("comic colour: the six", table.concat(registry.ComicColors, " "), "GREY YELLOW BLUE RED GREEN PURPLE")
check("comic colour: grey paper as before", frame.bg._vertex[1], 0.7)
check("comic colour: grey accent as stored", Themes.Accent(S("headerColor"))[3], 0.1)
check("comic colour: blue", registry.SetComicColor("BLUE"), true)
M.RunTimers()
check("comic colour: blue paper", frame.bg._vertex[3], 0.86)
check("comic colour: yellow accent", Themes.Accent(S("headerColor"))[2], 0.9)
check("comic colour: yellow", registry.SetComicColor("YELLOW"), true)
M.RunTimers()
check("comic colour: yellow paper", frame.bg._vertex[1], 0.86)
check("comic colour: blue accent", Themes.Accent(S("headerColor"))[3], 0.95)
check("comic colour: the look not stored", snapshot(), stored)
check("comic colour: unknown", select(2, registry.SetComicColor("PINK")), "UNKNOWN")
check("comic colour: unknown leaves it", registry.ComicColor(), "YELLOW")
M.state.combat = true
check("comic colour: combat", select(2, registry.SetComicColor("RED")), "COMBAT")
M.state.combat = false
Themes.Switch("WOOD")
M.RunTimers()
check("comic colour: kept away from comic", registry.ComicColor(), "YELLOW")
check("comic colour: no accent elsewhere", Themes.Accent(S("headerColor")), S("headerColor"))
check("comic colour: wood paper as it is", frame.bg._vertex[1], 0.5)
check("comic colour: picked under wood", registry.SetComicColor("GREEN"), true)
Themes.Switch("COMIC")
M.RunTimers()
check("comic colour: back to comic", frame.bg._vertex[2], 0.76)
check("comic colour: grey again", registry.SetComicColor("GREY"), true)
M.RunTimers()
check("comic colour: grey paper restored", frame.bg._vertex[1], 0.7)
check("comic colour: grey accent restored", Themes.Accent(S("headerColor"))[1], 1)
sets().comicColor = "PINK"
check("comic colour: unknown stored is grey", registry.ComicColor(), "GREY")
sets().comicColor = nil

Themes.Switch("WOOD")
check("wood: body keeps the theme font", S("objectiveFont"), "Cinzel")
check("wood: level colour as it is", ns.Themes.Ink(lvl), lvl)
check("tech: no corner pieces", Themes.SPECS.TECH.art, nil)
check("revision", Themes.REVISION, 3)
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
