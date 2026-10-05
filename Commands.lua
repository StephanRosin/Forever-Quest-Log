local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

function ns.ToggleLock()
    Settings.Set("locked", not Settings.Get("locked"))
    ns.Print(Settings.Get("locked") and L.MSG_LOCKED or L.MSG_UNLOCKED)
end

-- /fql status: what an error report needs.
local function status()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version, build = getMetadata and getMetadata(ADDON, "Version") or "?", select(1, GetBuildInfo())
    ns.Print("%s %s, %s %s (%s)", L.ADDON_NAME, version, L.STATUS_CLIENT, build or "?", select(2, GetBuildInfo()) or "?")
    if Settings.Get("useBlizzard") then
        ns.Print(L.STATUS_USING_BLIZZARD)
        return
    end
    local tracker = _G.ObjectiveTrackerFrame
    ns.Print("%s: %s (scale %.3f, alpha %.2f)", L.STATUS_BLIZZARD,
        ns.Blizzard.IsHidden() and L.STATUS_HIDDEN or L.STATUS_VISIBLE,
        tracker and tracker:GetScale() or 0, tracker and tracker:GetAlpha() or 0)
    ns.Print("%s: %d / %d, %s: %d", L.STATUS_WATCHED, C_QuestLog.GetNumQuestWatches(), ns.Data.MaxWatches(),
        L.STATUS_ITEMS, ns.Items.Count())
    if ns.Tracker.IsLayoutPending() then ns.Print(L.STATUS_PENDING) end
    for _, line in ipairs(ns.Blizzard.TaintReport()) do
        ns.Print("  %s: %s%s", line.name, line.secure and "|cff44dd44secure|r" or "|cffff4444tainted|r",
            line.by and (" (" .. line.by .. ")") or "")
    end
end

SLASH_FOREVERQUESTLOG1 = "/fql"
SLASH_FOREVERQUESTLOG2 = "/foreverquestlog"
SlashCmdList["FOREVERQUESTLOG"] = function(msg)
    local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
    if cmd == "" then
        ns.Window.Toggle()
    elseif cmd == "lock" then
        Settings.Set("locked", true)
        ns.Print(L.MSG_LOCKED)
    elseif cmd == "unlock" then
        Settings.Set("locked", false)
        ns.Print(L.MSG_UNLOCKED)
    elseif cmd == "status" then
        status()
    elseif cmd == "reset" then
        Settings.SetMany({ point = Settings.DEFAULTS.point, x = Settings.DEFAULTS.x, y = Settings.DEFAULTS.y,
            width = Settings.DEFAULTS.width, height = Settings.DEFAULTS.height })
        ns.Print(L.MSG_POSITION_RESET)
    else
        ns.Print(L.MSG_USAGE)
    end
end
