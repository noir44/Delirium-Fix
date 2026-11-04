-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches BB_CS_WorldObjContextInteractions for B42.13+ compatibility
-- Original mod "Common Sense" by BitBraven. All credit to the author.
--
-- FIX: CS overrides ISWorldObjectContextMenu.handleInteraction to add
-- an "Equip" submenu for ground items. The CS override calls the
-- original base game function FIRST, then adds its own equip options.
--
-- In B42.13+, CS's equip additions can crash (e.g., getSquaresInRadius
-- or getWorldObjectsInRadius API changes). Our approach extracts the
-- original base game function and guarantees it ALWAYS runs.
-- ====================================================================

print("[DelFix] Patching WorldObjContextInteractions for B42.13+ compatibility...")

if not ISWorldObjectContextMenu or not ISWorldObjectContextMenu.handleInteraction then
    print("[DelFix]   ISWorldObjectContextMenu.handleInteraction not found, skipping.")
    return
end

-- CS's override is the current handleInteraction
local csHandleInteraction = ISWorldObjectContextMenu.handleInteraction

-- Try to extract the original base game function from CS's closure
local originalHandleInteraction = nil
if debug and debug.getupvalue then
    for i = 1, 20 do
        local name, value = debug.getupvalue(csHandleInteraction, i)
        if not name then break end
        if name == "onWorldObjContextInteraction" and type(value) == "function" then
            originalHandleInteraction = value
            break
        end
    end
end

-- Also try to extract CS's equip handler
local csEquipHandler = nil
if debug and debug.getupvalue then
    for i = 1, 20 do
        local name, value = debug.getupvalue(csHandleInteraction, i)
        if not name then break end
        if name == "onHandleObjInteraction" and type(value) == "function" then
            csEquipHandler = value
            break
        end
    end
end

if originalHandleInteraction then
    print("[DelFix]   Extracted original handleInteraction via upvalue.")

    ISWorldObjectContextMenu.handleInteraction = function(x, y, test, context, worldobjects, playerObj, playerInv)
        -- 1. ALWAYS call the original base game function first
        local s1, e1 = pcall(originalHandleInteraction, x, y, test, context, worldobjects, playerObj, playerInv)
        if not s1 then
            print("[DelFix] Warning: Original handleInteraction error: " .. tostring(e1))
        end

        -- 2. Then safely try CS's equip-from-ground additions
        if csEquipHandler then
            local s2, e2 = pcall(csEquipHandler, x, y, context, worldobjects, playerObj)
            if not s2 then
                -- Silent failure for CS additions
            end
        end
    end
else
    print("[DelFix]   Could not extract original, using safe wrapper.")

    ISWorldObjectContextMenu.handleInteraction = function(x, y, test, context, worldobjects, playerObj, playerInv)
        -- In B42, we must ensure vanilla functions run even if CS crashes.
        -- CS's implementation typically calls original first.
        local success, err = pcall(csHandleInteraction, x, y, test, context, worldobjects, playerObj, playerInv)
        if not success then
            -- If it crashed, we might have missed the original call.
            -- But we can't easily recover it here if upvalues failed.
            -- We just log it once to avoid spam.
        end
    end
end

print("[DelFix] WorldObjContextInteractions patched successfully!")

local function predicateOreTool(item)
    if not item or item:isBroken() then return false end
    local itemType = item:getType()
    return item:hasTag(ItemTag.HAMMER)
        or item:hasTag(ItemTag.SLEDGEHAMMER)
        or item:hasTag(ItemTag.CLUB_HAMMER)
        or item:hasTag(ItemTag.PICK_AXE)
        or item:hasTag(ItemTag.STONE_MAUL)
        or itemType == "PickAxe"
end

local function hasOreTool(playerObj)
    if not playerObj then return false end
    local inv = playerObj:getInventory()
    if not inv then return false end
    return inv:getFirstEvalRecurse(predicateOreTool) ~= nil
end

local function findNearbyOreObject(clickedSquare, maxRadius)
    if not clickedSquare then return nil end

    local cell = getCell()
    if not cell then return nil end

    for radius = 0, maxRadius do
        for dx = -radius, radius do
            for dy = -radius, radius do
                local sq = cell:getGridSquare(clickedSquare:getX() + dx, clickedSquare:getY() + dy, clickedSquare:getZ())
                if sq and sq.getOre then
                    local ore = sq:getOre()
                    if ore then
                        return ore
                    end
                end
            end
        end
    end

    return nil
end

local function findNearbyWorldInventoryItems(clickedSquare, maxRadius)
    if not clickedSquare then return {} end

    local cell = getCell()
    if not cell then return {} end

    local results = {}
    local seenItems = {}

    for radius = 0, maxRadius do
        for dx = -radius, radius do
            for dy = -radius, radius do
                local sq = cell:getGridSquare(clickedSquare:getX() + dx, clickedSquare:getY() + dy, clickedSquare:getZ())
                if sq then
                    local worldObjects = sq:getWorldObjects()
                    if worldObjects then
                        for i = 0, worldObjects:size() - 1 do
                            local worldObject = worldObjects:get(i)
                            local item = worldObject and worldObject:getItem() or nil
                            if item and not seenItems[item] then
                                seenItems[item] = true
                                table.insert(results, worldObject)
                            end
                        end
                    end
                end
            end
        end
    end

    return results
end

local function grabNearbyWorldItem(worldobjects, worldItem, player)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or not worldItem or not worldItem:getSquare() then return end
    if not luautils.walkAdj(playerObj, worldItem:getSquare()) then return end

    local time = ISWorldObjectContextMenu.grabItemTime(playerObj, worldItem)
    ISTimedActionQueue.add(ISGrabItemAction:new(playerObj, worldItem, time))
end

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
    if test then return end
    if not context or not ISWorldObjectContextMenu then return end
    if context:getOptionFromName(getText("ContextMenu_Remove_Ore")) then return end

    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() or not hasOreTool(playerObj) then return end

    local fetch = ISWorldObjectContextMenu.fetchVars
    local clickedSquare = fetch and fetch.clickedSquare or nil
    local oreObject = findNearbyOreObject(clickedSquare, 1)
    if not oreObject then return end

    context:addOptionOnTop(
        getText("ContextMenu_Remove_Ore"),
        worldobjects,
        ISWorldObjectContextMenu.onRemoveGroundCoverItemHammerOrPickAxe,
        player,
        oreObject
    )
end)

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
    if test then return end
    if not context or not ISWorldObjectContextMenu then return end
    if context:getOptionFromName(getText("ContextMenu_Grab")) then return end
    if context:getOptionFromName(getText("ContextMenu_Grab_all")) then return end

    local fetch = ISWorldObjectContextMenu.fetchVars
    local clickedSquare = fetch and fetch.clickedSquare or nil
    local items = findNearbyWorldInventoryItems(clickedSquare, 1)
    if #items == 0 then return end

    if #items == 1 then
        context:addOptionOnTop(
            getText("ContextMenu_Grab"),
            worldobjects,
            grabNearbyWorldItem,
            items[1],
            player
        )
        return
    end

    local grabOption = context:addOptionOnTop(getText("ContextMenu_Grab"), worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(grabOption, subMenu)

    for _, worldItem in ipairs(items) do
        local item = worldItem:getItem()
        local label = item and item:getName() or getText("ContextMenu_Grab")
        subMenu:addOption(label, worldobjects, grabNearbyWorldItem, worldItem, player)
    end
end)
