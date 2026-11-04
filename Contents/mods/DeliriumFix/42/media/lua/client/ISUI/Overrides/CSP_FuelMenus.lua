-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches Fireplace, BBQ, and Camping fuel overrides
-- Original mod "Common Sense" by BitBraven. All credit to the author.
-- ====================================================================

print("[DelFix] Patching Fuel Menus for B42.13+ compatibility...")

-- ====================================================================
-- ROOT CAUSE ANALYSIS:
--
-- In B42, TIS completely replaced the fuel system:
--   - ISFireplaceMenu was REMOVED (confirmed: 0 files in game directory)
--   - ISFireplaceAddFuel was REMOVED (confirmed: 0 files in game directory)
--   - The new system uses AddFuelOption.lua (LootWindow handler) which
--     calls ISCampingMenu.doAddFuelOption() with ISBBQAddFuel timed action
--   - ISBBQAddFuel handles BOTH BBQ and IsoFireplace objects
--   - ISCampingMenu.onAddAllFuel signature is: (playerObj, target, timedAction, currentFuel)
--   - ISCampingMenu.onAddMultipleFuel signature is: (playerObj, target, fuelType, timedAction, currentFuel, count)
--
-- THE BUG: CS's original BB_CS_Fireplace.lua and BB_CS_Camping.lua overwrote
-- ISCampingMenu.onAddAllFuel with a function signature of (playerObj, campfire)
-- which has THE WRONG NUMBER OF ARGUMENTS. This breaks the base game's
-- fuel system when called from AddFuelOption.lua → ISCampingMenu.doAddFuelOption()
--
-- THE FIX: Restore ISCampingMenu.onAddAllFuel and onAddMultipleFuel to their
-- original base game implementations. Do NOT override them.
-- ====================================================================

-- ====================================================================
-- STEP 1: Restore ISCampingMenu fuel functions to base game originals
-- The CS mod overwrote these with broken signatures. We need to restore them.
-- ====================================================================
if ISCampingMenu and type(ISCampingMenu) == "table" then

    -- Check if CS has already broken the fuel functions by checking arg count
    -- The base game's onAddAllFuel takes 4 args: (playerObj, target, timedAction, currentFuel)
    -- CS's broken version takes 2 args: (playerObj, campfire)
    -- We restore by re-requiring the original file

    -- Save reference to the shared ArrayList used by the base game
    local fuelItemList = ArrayList.new()

    -- Restore onAddAllFuel with the CORRECT signature from base game
    ISCampingMenu.onAddAllFuel = function(playerObj, target, timedAction, currentFuel)
        local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
        if not containers then return end
        for i = 1, containers:size() do
            local container = containers:get(i - 1)
            if container then
                container:getAllEval(ISCampingMenu.isValidFuel, fuelItemList)
            end
        end

        -- Use the base game's internal addFuel helper
        if fuelItemList:isEmpty() then
            fuelItemList:clear()
            return
        end

        local max = fuelItemList:size()

        local fuelItems = ArrayList.new()
        for i = 1, max do
            fuelItems:add(fuelItemList:get(i - 1))
        end

        ISCampingMenu.toPlayerInventory(playerObj, fuelItems)

        if not ISCampingMenu.walkToCampfire(playerObj, target:getSquare()) then
            fuelItemList:clear()
            return
        end

        for i = 1, max do
            local fuelItem = fuelItems:get(i - 1)
            if playerObj:isEquipped(fuelItem) then
                ISTimedActionQueue.add(ISUnequipAction:new(playerObj, fuelItem, 50))
            end
            local fuelAmt = ISCampingMenu.getFuelDurationForItem(fuelItem)
            for j = 1, ISCampingMenu.getFuelItemUses(fuelItem) do
                if (currentFuel + (fuelAmt * j) > getCampingFuelMax()) then
                    fuelItemList:clear()
                    return
                end
                ISTimedActionQueue.add(timedAction:new(playerObj, target, fuelItem, fuelAmt))
            end
        end

        fuelItemList:clear()
    end

    -- Restore onAddMultipleFuel with the CORRECT signature from base game
    ISCampingMenu.onAddMultipleFuel = function(playerObj, target, fuelType, timedAction, currentFuel, count)
        local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
        if not containers then return end
        for i = 1, containers:size() do
            local container = containers:get(i - 1)
            if container then
                container:getAllTypeEval(fuelType, ISCampingMenu.isValidFuel, fuelItemList)
            end
        end

        if fuelItemList:isEmpty() then
            fuelItemList:clear()
            return
        end

        local max = fuelItemList:size()
        if count then max = count end

        local fuelItems = ArrayList.new()
        for i = 1, max do
            fuelItems:add(fuelItemList:get(i - 1))
        end

        ISCampingMenu.toPlayerInventory(playerObj, fuelItems)

        if not ISCampingMenu.walkToCampfire(playerObj, target:getSquare()) then
            fuelItemList:clear()
            return
        end

        for i = 1, max do
            local fuelItem = fuelItems:get(i - 1)
            if playerObj:isEquipped(fuelItem) then
                ISTimedActionQueue.add(ISUnequipAction:new(playerObj, fuelItem, 50))
            end
            local fuelAmt = ISCampingMenu.getFuelDurationForItem(fuelItem)
            for j = 1, ISCampingMenu.getFuelItemUses(fuelItem) do
                if (currentFuel + (fuelAmt * j) > getCampingFuelMax()) then
                    fuelItemList:clear()
                    return
                end
                ISTimedActionQueue.add(timedAction:new(playerObj, target, fuelItem, fuelAmt))
            end
        end

        fuelItemList:clear()
    end

    -- Restore onAddFuel with the CORRECT signature
    ISCampingMenu.onAddFuel = function(playerObj, target, fuelType, timedAction, currentFuel)
        local fuelItem = nil
        local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
        for i = 1, containers:size() do
            fuelItem = containers:get(i - 1):getFirstTypeEvalRecurse(fuelType, ISCampingMenu.isValidFuel)
            if fuelItem then break end
        end
        if not fuelItem then return end
        local fuelAmt = ISCampingMenu.getFuelDurationForItem(fuelItem)
        ISCampingMenu.toPlayerInventory(playerObj, fuelItem)
        if not ISCampingMenu.walkToCampfire(playerObj, target:getSquare()) then return end
        ISTimedActionQueue.add(timedAction:new(playerObj, target, fuelItem, fuelAmt))
    end

    print("[DelFix]   ISCampingMenu fuel functions RESTORED to base game signatures!")
    print("[DelFix]   (CS had overwritten them with wrong arg counts, breaking fireplaces/stoves)")
else
    print("[DelFix]   ISCampingMenu not found, skipping fuel restoration.")
end

-- ====================================================================
-- STEP 2: ISFireplaceMenu / ISBBQMenu stubs
-- These don't exist in B42 anymore. Our stubs in CSP_Utils.lua prevent
-- CS from crashing when it tries to set functions on them.
-- We don't need to do anything else here - the new B42 system
-- (AddFuelOption.lua + ISBBQAddFuel) handles everything.
-- ====================================================================

print("[DelFix] Fuel system patch complete!")
print("[DelFix]   B42 fuel chain: AddFuelOption → ISCampingMenu.doAddFuelOption → ISBBQAddFuel")
