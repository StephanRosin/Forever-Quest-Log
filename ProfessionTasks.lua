local ADDON, ns = ...
local L = ns.L

-- A "+ To-do" button in Blizzard's profession window: the shown recipe's
-- reagents, times the amount in the window's craft box, go onto an existing
-- task list or a new one named after the recipe. Only a child frame of the
-- form and read calls: no hooks, no fields written on Blizzard's frames.
local ProfessionTasks = {}
ns.ProfessionTasks = ProfessionTasks

local function craftCount(page)
    local box = page and page.CreateMultipleInputBox
    local n = box and box.GetValue and tonumber(box:GetValue())
    return n and n >= 1 and math.floor(n) or 1
end

local function add(list, recipeID, count)
    if ns.Tasks.AddRecipe(list, recipeID, count) == 0 then ns.Print(L.TASK_RECIPE_UNKNOWN) end
end

-- The menu: every list, then a new one.
function ProfessionTasks.Menu(owner, recipeID, name, count)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(count > 1 and ("%s x%d"):format(name, count) or name)
        for _, list in ipairs(ns.Tasks.Lists()) do
            root:CreateButton(list.name, function() add(list, recipeID, count) end)
        end
        root:CreateButton(L.TASK_RECIPE_NEW_LIST, function()
            local list = ns.Tasks.AddList(name)
            if list then add(list, recipeID, count) end
        end)
    end)
end

function ProfessionTasks.Build()
    local page = _G.ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    if ProfessionTasks.button or not (form and form.TrackRecipeCheckbox and MenuUtil) then return end
    local b = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    b:SetText(L.TASK_RECIPE_BUTTON)
    b:SetSize(b:GetTextWidth() + 24, 22)
    b:SetPoint("RIGHT", form.TrackRecipeCheckbox, "LEFT", -6, 0)
    b:SetScript("OnClick", function(self)
        local info = form.GetRecipeInfo and form:GetRecipeInfo()
        if not info then return end
        ProfessionTasks.Menu(self, info.recipeID, info.name or "", craftCount(page))
    end)
    ProfessionTasks.button = b
end

ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_Professions" then ProfessionTasks.Build() end
end)
ns.On("PLAYER_LOGIN", function() ProfessionTasks.Build() end)
