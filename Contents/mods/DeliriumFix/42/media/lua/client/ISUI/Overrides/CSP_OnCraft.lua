-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches BB_CS_OnCraft for B42.13+ compatibility
-- Original mod "Common Sense" by BitBraven. All credit to the author.
-- ====================================================================

print("[DelFix] Patching OnCraft for B42.13+ compatibility...")

-- ====================================================================
-- FIX: ISInventoryPaneContextMenu.OnCraft override
-- The original OnCraft override may fail if recipe:getOriginalname()
-- or other recipe APIs changed in B42.13+.
-- We wrap the existing override in a pcall safety net.
-- ====================================================================

if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.OnCraft then

    local currentOnCraft = ISInventoryPaneContextMenu.OnCraft

    ISInventoryPaneContextMenu.OnCraft = function(selectedItem, recipe, player, all)
        local success, err = pcall(currentOnCraft, selectedItem, recipe, player, all)
        if not success then
            print("[DelFix] Warning: OnCraft error: " .. tostring(err))
            -- Try to get the original base game function as fallback
            -- The CS mod stores it as a local upvalue, so we can't access it.
            -- Best we can do is report the error.
        end
    end

    print("[DelFix]   OnCraft patched!")
else
    print("[DelFix]   ISInventoryPaneContextMenu.OnCraft not found, skipping.")
end

print("[DelFix] OnCraft patch complete!")
