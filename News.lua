local ADDON, ns = ...
local L = ns.L

-- The announcement of a big release: once per account, the standard popup, a
-- moment after the loading screen and out of combat. A small release leaves
-- VERSION and the text alone, so nothing shows; a big one changes both.
local News = {}
ns.News = News

News.VERSION = "0.4.4"
local SHOW_DELAY = 3    -- seconds: UIParent showing after the loading screen closes open windows
local DIALOG = "FOREVERQUESTLOG_NEWS"

StaticPopupDialogs[DIALOG] = {
    text = "",
    button1 = OKAY or "OK",
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function News.Due()
    return ForeverQuestLogProfiles.newsSeen ~= News.VERSION
end

local pending = false

local function show()
    pending = false
    if not News.Due() then return end
    StaticPopupDialogs[DIALOG].text = ("%s %s\n\n%s"):format(L.ADDON_NAME, News.VERSION, L.NEWS_TEXT)
    -- Recorded only if it really showed, or it could never be seen.
    if StaticPopup_Show(DIALOG) then ForeverQuestLogProfiles.newsSeen = News.VERSION end
end

-- A new player has nothing to be told what changed.
ns.On("PLAYER_LOGIN", function()
    ns.CharState()  -- runs the profiles' first setup, which tells a fresh install
    if ns.freshInstall then ForeverQuestLogProfiles.newsSeen = News.VERSION end
end)

ns.On("LOADING_SCREEN_DISABLED", function()
    if pending or not News.Due() then return end
    pending = true
    C_Timer.After(SHOW_DELAY, function() ns.AfterCombat("news", show) end)
end)
