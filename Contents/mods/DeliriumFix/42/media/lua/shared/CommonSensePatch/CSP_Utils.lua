-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches BB_CS_Utils for Build 42.13.2+ compatibility
-- Original mod "Common Sense" by BitBraven. All credit to the author.
-- ====================================================================

-- ====================================================================
-- CRITICAL FIX: Pre-define tables removed in B42.14
-- ====================================================================
if not ISFireplaceMenu or type(ISFireplaceMenu) ~= "table" then
    ISFireplaceMenu = {}
end

if not ISBBQMenu or type(ISBBQMenu) ~= "table" then
    ISBBQMenu = {}
end

-- Ensure BB_CS_Utils exists (loaded by original mod first)
if not BB_CS_Utils then
    print("[DelFix] ERROR: BB_CS_Utils not found. Is Common Sense loaded?")
    return
end

print("[DelFix] Patching BB_CS_Utils for B42.13+ compatibility...")

-- ====================================================================
-- FIX 1: TryPlaySoundClip
-- ====================================================================
BB_CS_Utils.TryPlaySoundClip = function(obj, soundName)
    if not obj or not soundName then return end
    local emitter = obj:getEmitter()
    if not emitter or emitter:isPlaying(soundName) then return end
    emitter:playSound(soundName)
end

-- ====================================================================
-- FIX 2: TryStopSoundClip
-- ====================================================================
BB_CS_Utils.TryStopSoundClip = function(obj, soundName)
    if not obj or not soundName then return end
    local emitter = obj:getEmitter()
    if not emitter or not emitter:isPlaying(soundName) then return end
    emitter:stopSoundByName(soundName)
end

-- ====================================================================
-- FIX 3: GetProperSound
-- ====================================================================
BB_CS_Utils.GetProperSound = function(priableObject, getSoundType)
    local isGarage = false
    if buildUtil and buildUtil.getGarageDoorObjects then
        local success, result = pcall(buildUtil.getGarageDoorObjects, priableObject)
        if success and result and #result > 0 then isGarage = true end
    end

    if not isGarage then
        return getSoundType and "Wooden" or "BeginRemoveBarricadePlank"
    else
        return getSoundType and "Metal" or "PrisonMetalDoorBlocked"
    end
end

-- ====================================================================
-- FIX 4: TirePlayer
-- ====================================================================
BB_CS_Utils.TirePlayer = function(playerObj, amount)
    if not playerObj then return end
    local stats = playerObj:getStats()
    if not stats or not stats.getEndurance or not stats.setEndurance then return end
    
    local endurance = stats:getEndurance()
    if not endurance or endurance < 0.21 then return end

    local fitness = (Perks and Perks.Fitness and playerObj.getPerkLevel) and playerObj:getPerkLevel(Perks.Fitness) or 5
    stats:setEndurance(endurance - (amount / (math.max(fitness, 1) / 2)))
end

-- ====================================================================
-- FIX 5: addTooltip
-- ====================================================================
BB_CS_Utils.addTooltip = function(description, menuOption)
    if not menuOption or not description or not ISWorldObjectContextMenu or not ISWorldObjectContextMenu.addToolTip then return end
    local success, tooltip = pcall(ISWorldObjectContextMenu.addToolTip)
    if success and tooltip then
        tooltip.description = description
        menuOption.toolTip = tooltip
    end
end

-- ====================================================================
-- MP SYNC HELPERS: Define CSServer.Request functions in shared
-- to ensure they are ALWAYS available on the client in MP.
-- ====================================================================
if not CSServer then CSServer = {} end

CSServer.RequestPryDoorOpen = function(worldObjects, priableObject, playerObj)
    if not priableObject or not playerObj then return end
    if isClient() then
        local sq = priableObject:getSquare()
        if sq then
            sendClientCommand(playerObj, "DelFix", "PryDoorOpen", {
                x = sq:getX(), y = sq:getY(), z = sq:getZ(),
                objectType = instanceof(priableObject, "IsoDoor") and "IsoDoor" or "IsoWindow"
            })
        end
    else
        if CSServer.PryDoorOpen then CSServer.PryDoorOpen(worldObjects, priableObject, playerObj) end
    end
end

CSServer.RequestPryVehicleDoorOpen = function(vehicle, vehiclePart, playerObj)
    if not vehicle or not vehiclePart or not playerObj then return end
    if isClient() then
        sendClientCommand(playerObj, "DelFix", "PryVehicleDoorOpen", {
            vehicleId = vehicle:getId(), partId = vehiclePart:getId()
        })
    else
        if CSServer.PryVehicleDoorOpen then CSServer.PryVehicleDoorOpen(vehicle, vehiclePart, playerObj) end
    end
end

print("[DelFix] BB_CS_Utils and MP Helpers patched successfully!")
