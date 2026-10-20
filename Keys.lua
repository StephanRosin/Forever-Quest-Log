local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

-- Key bindings (Bindings.xml): what each key does, the names shown under
-- Key Bindings -> Forever Quest Log, and reading / setting the keys for the
-- options page. The keys are WoW's own bindings, saved with the binding set
-- (account or character), not in the profile.
local Keys = {}
ns.Keys = Keys

local PREFIX = "FOREVERQUESTLOG_"

Keys.ACTIONS = {
    { id = "COLLAPSE", label = "BIND_COLLAPSE", run = function() ns.Tracker.ToggleCollapse() end },
    { id = "HIDECOMPLETE", label = "BIND_HIDE_COMPLETE",
      run = function() Settings.Set("hideCompleteQuests", not Settings.Get("hideCompleteQuests")) end },
    { id = "LOCK", label = "BIND_LOCK", run = function() ns.ToggleLock() end },
    { id = "OPTIONS", label = "BIND_OPTIONS", run = function() ns.Window.Toggle() end },
}

local byId = {}
for _, action in ipairs(Keys.ACTIONS) do byId[action.id] = action end

BINDING_HEADER_FOREVERQUESTLOG = L.ADDON_NAME
BINDING_NAME_FOREVERQUESTLOG_COLLAPSE = L.BIND_COLLAPSE
BINDING_NAME_FOREVERQUESTLOG_HIDECOMPLETE = L.BIND_HIDE_COMPLETE
BINDING_NAME_FOREVERQUESTLOG_LOCK = L.BIND_LOCK
BINDING_NAME_FOREVERQUESTLOG_OPTIONS = L.BIND_OPTIONS

function ForeverQuestLog_Binding(id)
    byId[id].run()
end

-- The first key bound to the action, or nil.
function Keys.Get(id)
    return (GetBindingKey(PREFIX .. id))
end

-- "CTRL-Q" for the key just pressed with the modifiers held, as Blizzard's
-- key binding page builds it; nil for a modifier on its own.
function Keys.Combination(key)
    if IsKeyPressIgnoredForBinding(key) then return nil end
    return CreateKeyChordStringUsingMetaKeyState(key)
end

-- Binds key to the action (nil: no key), replacing its old keys; WoW refuses
-- binding changes in combat. Says which action lost the key, if any.
function Keys.Set(id, key)
    if InCombatLockdown() then
        ns.Print(L.MSG_KEYS_COMBAT)
        return
    end
    local command = PREFIX .. id
    for _, old in ipairs({ GetBindingKey(command) }) do SetBinding(old) end
    if key then
        local previous = GetBindingAction(key)
        if previous and previous ~= "" and previous ~= command then
            ns.Print(L.MSG_KEY_REPLACED:format(GetBindingText(key), _G["BINDING_NAME_" .. previous] or previous))
        end
        SetBinding(key, command)
    end
    SaveBindings(GetCurrentBindingSet())
end
