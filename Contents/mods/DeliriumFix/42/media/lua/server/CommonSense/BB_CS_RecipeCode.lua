-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Override for BB_CS_RecipeCode.lua
-- Original mod "Common Sense" by BitBraven. All credit to the author.
-- 
-- In B42.13+, Recipe.GetItemTypes may not be a table, or may not exist,
-- causing "attempted index of non-table" error at line 13.
-- This replacement safely checks before defining the function.
-- ====================================================================

-- Safe require: recipecode may fail in B42.13+
local success = pcall(require, "recipecode")
if not success then
    print("[DelFix] Warning: require('recipecode') failed, skipping Recipe.GetItemTypes override")
    return
end

-- Only define the function if Recipe and Recipe.GetItemTypes exist as tables
if Recipe and type(Recipe) == "table" then
    if not Recipe.GetItemTypes then
        Recipe.GetItemTypes = {}
    end

    if type(Recipe.GetItemTypes) == "table" then
        Recipe.GetItemTypes.Scissors = function(scriptItems)
            local sm = getScriptManager()
            if not sm then return end

            local success1, result1 = pcall(function()
                return sm:getItemsTag("SharpKnife")
            end)
            if success1 and result1 then
                pcall(function() scriptItems:addAll(result1) end)
            end

            local success2, result2 = pcall(function()
                return sm:getItemsTag("Scissors")
            end)
            if success2 and result2 then
                pcall(function() scriptItems:addAll(result2) end)
            end
        end
        print("[DelFix] BB_CS_RecipeCode patched successfully!")
    else
        print("[DelFix] Warning: Recipe.GetItemTypes is not a table, skipping override")
    end
else
    print("[DelFix] Warning: Recipe table not found, skipping RecipeCode override")
end
