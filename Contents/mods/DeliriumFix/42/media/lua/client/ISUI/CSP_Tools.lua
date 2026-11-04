-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches the Prying/Crowbar tools for Build 42.13.2+ compatibility
-- Original mod "Common Sense" by BitBraven. All credit to the author.
-- ====================================================================

-- Wait for CSUtils to be defined by the original mod
if not CSUtils then
    print("[DelFix] ERROR: CSUtils not found. Is Common Sense loaded?")
    print("[DelFix] Please ensure Common Sense (BB_CommonSense) is installed and enabled.")
    return
end

-- Double-check Common Sense is in active mods
if not getActivatedMods or not getActivatedMods():contains("BB_CommonSense") then
    print("[DelFix] WARNING: Common Sense (BB_CommonSense) not detected in active mods!")
    print("[DelFix] CSUtils exists but mod not listed - possible load order issue.")
end

print("[DelFix] Patching CSUtils (Prying Tools) for B42.13+ compatibility...")

-- ====================================================================
-- FIX 1: playerHasPryingTool - Missing return true!
-- ====================================================================
CSUtils.playerHasPryingTool = function(playerObj, itemID, override)
    if override then return true end
    if not playerObj then return false end
    if not itemID then return false end

    local playerInv = playerObj:getInventory()
    if not playerInv then return false end

    local pryingTool = playerInv:getFirstTypeEvalRecurse(itemID, CSUtils.predicateNotBroken)

    if not pryingTool then return false end
    return true
end

-- ====================================================================
-- FIX 2: PryEntityOpen - Add safety checks
-- ====================================================================
CSUtils.PryEntityOpen = function(worldobjects, priableObject, playerObj, pryingTool)
    if not playerObj or not priableObject or not pryingTool then return end

    local toolID = pryingTool:getFullType()
    local toolContainer = nil

    pcall(ISInventoryPaneContextMenu.transferIfNeeded, playerObj, pryingTool)

    if not playerObj:hasEquipped(toolID) then
        ISInventoryPaneContextMenu.equipWeapon(pryingTool, true, true, playerObj:getPlayerNum())
        toolContainer = pryingTool:getContainer()
    end

    if not playerObj:hasEquipped(toolID) then
        CSUtils.Loop(worldobjects, playerObj, priableObject, "PryDoor", toolID, toolContainer)
    else
        if priableObject:getSquare() then
            luautils.walkAdjWindowOrDoor(playerObj, priableObject:getSquare(), priableObject)
        end
        ISTimedActionQueue.add(CSISTimedAction:PryDoor(worldobjects, priableObject, playerObj, toolContainer, 190))
    end
end

-- ====================================================================
-- FIX 3: PryVehicleOpen - Add safety checks
-- ====================================================================
CSUtils.PryVehicleOpen = function(vehicle, vehiclePart, playerObj, pryingTool)
    if not playerObj or not vehicle or not vehiclePart or not pryingTool then return end

    local toolID = pryingTool:getFullType()
    local toolContainer = nil

    pcall(ISInventoryPaneContextMenu.transferIfNeeded, playerObj, pryingTool)

    if not playerObj:hasEquipped(toolID) then
        ISInventoryPaneContextMenu.equipWeapon(pryingTool, true, true, playerObj:getPlayerNum())
        toolContainer = pryingTool:getContainer()
    end

    if not playerObj:hasEquipped(toolID) then
        CSUtils.Loop(vehicle, playerObj, vehiclePart, "PryVehicleDoor", toolID, toolContainer)
    else
        ISTimedActionQueue.add(CSISTimedAction:PryVehicleDoor(vehicle, vehiclePart, playerObj, toolContainer, 190))
    end
end

-- ====================================================================
-- FIX 4: Loop - Add safety to the delayed loop function
-- ====================================================================
CSUtils.Loop = function(worldobjects, playerObj, priableObject, actionType, toolID, toolContainer)
    if not playerObj then return end

    if not playerObj:hasEquipped(toolID) then
        BB_CS_Utils.DelayFunction(function()
            if not playerObj or not playerObj:hasEquipped(toolID) then
                if playerObj then CSUtils.Loop(worldobjects, playerObj, priableObject, actionType, toolID, toolContainer) end
            else
                if actionType == "PryDoor" then
                    if priableObject and priableObject:getSquare() then
                        luautils.walkAdjWindowOrDoor(playerObj, priableObject:getSquare(), priableObject)
                    end
                    ISTimedActionQueue.add(CSISTimedAction:PryDoor(worldobjects, priableObject, playerObj, toolContainer, 190))
                elseif actionType == "PryVehicleDoor" then
                    ISTimedActionQueue.add(CSISTimedAction:PryVehicleDoor(worldobjects, priableObject, playerObj, toolContainer, 190))
                end
            end
        end, 10, true)
    end
end

-- ====================================================================
-- FIX 5: OnFillWorldObjectContextMenuCrowbar - Safety wrapper
-- ====================================================================

local function safeGetGarageDoorObjects(obj)
    if not buildUtil or not buildUtil.getGarageDoorObjects then return {} end
    local success, result = pcall(buildUtil.getGarageDoorObjects, obj)
    if success and result then return result end
    return {}
end

local function getArrayListSize(list)
    if not list then return 0 end
    if type(list) == "table" then return #list end
    if list.size then return list:size() end
    return 0
end

local function safeIsThumpDoor(obj)
    if not obj then return false end
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.isThumpDoor then
        local success, result = pcall(ISWorldObjectContextMenu.isThumpDoor, obj)
        if success then return result == true end
    end
    if instanceof(obj, "IsoDoor") or instanceof(obj, "IsoWindow") then return true end
    if instanceof(obj, "IsoThumpable") and obj:isDoor() then return true end
    
    local garageDoorObjects = safeGetGarageDoorObjects(obj)
    if getArrayListSize(garageDoorObjects) > 0 then return true end
    
    return false
end

local function resolveGarageDoorRoot(obj)
    local gdoList = safeGetGarageDoorObjects(obj)
    local gdoSz = getArrayListSize(gdoList)
    if gdoSz <= 0 then
        return obj
    end

    for i = 1, gdoSz do
        local part = type(gdoList) == "table" and gdoList[i] or gdoList:get(i - 1)
        if part and (instanceof(part, "IsoDoor") or (instanceof(part, "IsoThumpable") and part:isDoor())) then
            return part
        end
    end

    return obj
end

local function findPriableObjectNearSquare(clickedSquare, maxRadius)
    if not clickedSquare then return nil end

    local cell = getCell()
    if not cell then return nil end

    for radius = 0, maxRadius do
        for dx = -radius, radius do
            for dy = -radius, radius do
                local sq = cell:getGridSquare(clickedSquare:getX() + dx, clickedSquare:getY() + dy, clickedSquare:getZ())
                if sq then
                    local objs = sq:getObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            if safeIsThumpDoor(obj) then
                                return resolveGarageDoorRoot(obj)
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local original_OnFillWorldObjectContextMenuCrowbar = CSUtils.OnFillWorldObjectContextMenuCrowbar

CSUtils.OnFillWorldObjectContextMenuCrowbar = function(player, context, worldobjects, test)
    -- GLOBAL SAFETY WRAPPER for this function to prevent breaking other menus
    local success, err = pcall(function()
        if not SandboxVars.CommonSense or not SandboxVars.CommonSense.PryingMechanic then return end

        local playerObj = getSpecificPlayer(player)
        if not playerObj or playerObj:getVehicle() then return end

        local playerInv = playerObj:getInventory()
        if not playerInv then return end

        local pryingTool = nil
        if CommonSense and CommonSense.PryingTools then
            for _, v in pairs(CommonSense.PryingTools) do
                pryingTool = playerInv:getFirstTypeEvalRecurse(v, CSUtils.predicateNotBroken)
                if pryingTool then break end
            end
        end

        if not pryingTool then return end

        local priableObject = nil
        for _, v in ipairs(worldobjects) do
            if safeIsThumpDoor(v) then
                priableObject = v
                break
            end
        end

        -- Nearby squares search. Garage doors can be picked from an offset tile
        -- depending on isometric quadrant, so a 1-tile search is not enough.
        local fetch = ISWorldObjectContextMenu.fetchVars
        if fetch and fetch.clickedSquare and not priableObject then
            priableObject = findPriableObjectNearSquare(fetch.clickedSquare, 2)
        end

        if priableObject ~= nil then
            priableObject = resolveGarageDoorRoot(priableObject)

            local isReinforcedDoor = false
            local canPryOpenReinforcedDoors = SandboxVars.CommonSense.PrySafeDoors == true

            if canPryOpenReinforcedDoors then
                local strengthLevel = playerObj:getPerkLevel(Perks.Strength)
                if strengthLevel < (SandboxVars.CommonSense.ReinforcedDoorLevel or 8) then
                    canPryOpenReinforcedDoors = false
                end
            end

            local sprite = priableObject:getSprite()
            if sprite then
                local spriteName = sprite:getName() or ""
                if spriteName == "fixtures_doors_01_32" or spriteName == "fixtures_doors_01_33" or
                   spriteName == "location_community_police_01_4" or spriteName == "location_community_police_01_5" then
                    isReinforcedDoor = true
                end
            end

            if instanceof(priableObject, "IsoDoor") and priableObject:isLocked() and not priableObject:isBarricaded() then
                local isGarage = false
                local garageDoorObjects = safeGetGarageDoorObjects(priableObject)
                if getArrayListSize(garageDoorObjects) > 0 then
                    if not SandboxVars.CommonSense.PryGarageDoors then return end
                    isGarage = true
                end

                if isReinforcedDoor and not SandboxVars.CommonSense.PrySafeDoors then return end
                if not (SandboxVars.CommonSense.PryBuildingDoors or isGarage or (isReinforcedDoor and SandboxVars.CommonSense.PrySafeDoors)) then return end

                local option = context:addOptionOnTop(getText("ContextMenu_Pry_open"), worldobjects, CSUtils.PryEntityOpen, priableObject, playerObj, pryingTool)
                local description = getText("Tooltip_CS_PryOpenDoor")

                if isReinforcedDoor and not canPryOpenReinforcedDoors then
                    description = string.format(getText("Tooltip_CS_CantPryOpenRDoor"), SandboxVars.CommonSense.ReinforcedDoorLevel)
                    option.notAvailable = true
                end

                BB_CS_Utils.addTooltip(description, option)
                return
            end

            if instanceof(priableObject, "IsoWindow") and not priableObject:IsOpen() and SandboxVars.CommonSense.PryWindows then
                local option = context:addOptionOnTop(getText("ContextMenu_Pry_open"), worldobjects, CSUtils.PryEntityOpen, priableObject, playerObj, pryingTool)
                local description = getText("Tooltip_CS_PryOpenWindow")

                if priableObject:IsOpen() or priableObject:isPermaLocked() or priableObject:isBarricaded() or priableObject:isSmashed() then
                    description = getText("Tooltip_CS_CantPryOpenWindow")
                    option.notAvailable = true
                end

                BB_CS_Utils.addTooltip(description, option)
                return
            end
        end
    end)
    
    if not success then
        print("[DelFix] Warning: OnFillWorldObjectContextMenuCrowbar crashed: " .. tostring(err))
    end
end

-- ====================================================================
-- FIX 7: PrySuccessfully - Safety fixes
-- ====================================================================
CSUtils.PrySuccessfully = function(playerObj, failBoost)
    if not playerObj then return false end

    local isBurglar = false
    if playerObj.getTraits then
        local traits = playerObj:getTraits()
        if traits and traits.size then
            for i = 0, traits:size() - 1 do
                local t = traits:get(i)
                if t and (tostring(t) == "Burglar" or (t.getType and t:getType() == "Burglar")) then
                    isBurglar = true
                    break
                end
            end
        end
    end

    if isBurglar then
        return ZombRand(10) > 1
    end

    local strengthLevel = 5
    if Perks and Perks.Strength and playerObj.getPerkLevel then
        strengthLevel = playerObj:getPerkLevel(Perks.Strength)
    end
    if not strengthLevel or strengthLevel < 1 then strengthLevel = 1 end

    local succeedChance = ZombRand(100)
    local failChance = (180 / strengthLevel) + failBoost

    if SandboxVars.CommonSense and SandboxVars.CommonSense.PryingChanceMultiplier then
        failChance = failChance * SandboxVars.CommonSense.PryingChanceMultiplier
    end

    return succeedChance > failChance
end

-- ====================================================================
-- FIX 6: showRadialMenuOutsideCrowbar - Safety for vehicle prying
-- ====================================================================
CSUtils.showRadialMenuOutsideCrowbar = function(playerObj)
    pcall(function()
        if not SandboxVars.CommonSense or not SandboxVars.CommonSense.PryingMechanic or not SandboxVars.CommonSense.PryVehicleDoors then return end

        local vehicle = playerObj:getNearVehicle()
        if not vehicle then return end

        local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
        if not menu then return end

        local playerInv = playerObj:getInventory()
        if not playerInv then return end

        local pryingTool = nil
        if CommonSense and CommonSense.PryingTools then
            for _, v in pairs(CommonSense.PryingTools) do
                pryingTool = playerInv:getFirstTypeEvalRecurse(v, CSUtils.predicateNotBroken)
                if pryingTool then break end
            end
        end

        if not pryingTool then return end

        local doorPart = vehicle:getUseablePart(playerObj)
        if doorPart and doorPart:getDoor() and doorPart:getInventoryItem() then
            if not doorPart:getDoor():isLocked() then return end
            menu:addSlice(getText("ContextMenu_Pry_open"), getTexture("media/ui/vehicles/PryOpen.png"), CSUtils.PryVehicleOpen, vehicle, doorPart, playerObj, pryingTool)
        end
    end)
end

print("[DelFix] CSUtils (Prying Tools) patched successfully!")
