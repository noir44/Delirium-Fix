-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches CSServer for Build 42.13.2+ compatibility
-- ====================================================================

if not CSServer then return end

-- ====================================================================
-- SERVER-SIDE authoritative logic
-- ====================================================================
CSServer.PryDoorOpen = function(worldObjects, priableObject, playerObj)
    if not priableObject or not playerObj then return end

    if instanceof(priableObject, "IsoDoor") then
        priableObject:setLockedByKey(false)
        if buildUtil and buildUtil.getDoubleDoorObjects then
            local ddo = buildUtil.getDoubleDoorObjects(priableObject)
            if ddo then for i = 1, #ddo do ddo[i]:setLockedByKey(false) end end
        end
        if buildUtil and buildUtil.getGarageDoorObjects then
            local gdo = buildUtil.getGarageDoorObjects(priableObject)
            if gdo then for i = 1, #gdo do gdo[i]:setLockedByKey(false) end end
        end
        -- B42.14 FIX: Do NOT use ISTimedActionQueue.add(ISOpenCloseDoor:new(...)) here!
        -- This function is called from CSISTimedAction.perform(), and adding to the queue
        -- during perform() causes a Java NullPointerException (callFrame null in StartAction).
        -- Instead, directly toggle the door open using the game's API.
        pcall(function()
            if priableObject:IsOpen() then return end  -- already open, nothing to do
            priableObject:ToggleDoor(playerObj)
        end)
        if priableObject.sendObjectChange then priableObject:sendObjectChange("lockByKey") end
        BB_CS_Utils.TryPlaySoundClip(playerObj, "BreakBarricadePlank")
        playerObj:getXp():AddXP(Perks.Strength, 7)
    elseif instanceof(priableObject, "IsoWindow") then
        local shatter = ZombRand(100) < (SandboxVars.CommonSense.WindowShatterChance or 20)
        if not shatter then
            priableObject:setIsLocked(false)
            priableObject:setPermaLocked(false)
            pcall(function() ISWorldObjectContextMenu.onOpenCloseWindow(nil, priableObject, playerObj:getPlayerNum()) end)
            if priableObject.sendObjectChange then priableObject:sendObjectChange("lock") end
            playerObj:getXp():AddXP(Perks.Strength, 4)
        else
            priableObject:setSmashed(true)
            if priableObject.sendObjectChange then priableObject:sendObjectChange("smash") end
            BB_CS_Utils.TryPlaySoundClip(playerObj, "SmashWindow")
            playerObj:getXp():AddXP(Perks.Strength, 3)
        end
    end
end

CSServer.PryVehicleDoorOpen = function(vehicle, vehiclePart, playerObj)
    if not vehicle or not vehiclePart then return end
    local door = vehiclePart:getDoor()
    if door then
        door:setLocked(false)
        door:setOpen(true)
        if door.setLockBroken then door:setLockBroken(true) end
        if vehicle.setAnyDoorLocked then vehicle:setAnyDoorLocked(false) end
        vehicle:transmitPartDoor(vehiclePart)
        if isServer() then vehicle:sendVars() end
    end
end

-- ====================================================================
-- SERVER COMMAND HANDLER
-- ====================================================================
local function onClientCommand(module, command, playerObj, args)
    if module == "DelFix" then
        if command == "PryDoorOpen" then
            local sq = getCell():getGridSquare(args.x, args.y, args.z)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if obj and instanceof(obj, args.objectType) then
                        CSServer.PryDoorOpen(nil, obj, playerObj)
                        break
                    end
                end
            end
        elseif command == "PryVehicleDoorOpen" then
            local vehicle = getVehicleByID(args.vehicleId)
            if vehicle then
                local allParts = vehicle:getParts()
                for i=0, allParts:size()-1 do
                    local p = allParts:get(i)
                    if p:getId() == args.partId then
                        CSServer.PryVehicleDoorOpen(vehicle, p, playerObj)
                        break
                    end
                end
            end
        elseif command == "CollectItems" then
            local playerInv = playerObj:getInventory()
            if playerInv then
                local multiplier = args.lootMultiplier or 1
                for itemStr in string.gmatch(args.itemsList, "([^,]+)") do
                    local name, countStr = itemStr:match("^(.+):(%d+)$")
                    if name and countStr then
                        local count = math.floor(tonumber(countStr) * multiplier)
                        for i = 1, count do 
                            local item = playerInv:AddItem(name)
                            if isServer() and item then
                                sendAddItemToContainer(playerInv, item)
                            end
                        end
                    end
                end
                -- FORCE REFRESH FOR B42.14
                if isServer() then
                    playerObj:sendInventoryToClient()
                    playerInv:setDrawDirty(true)
                    playerInv:setInventoryDirty(true)
                end
            end
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
print("[DelFix] Server initialized successfully!")
