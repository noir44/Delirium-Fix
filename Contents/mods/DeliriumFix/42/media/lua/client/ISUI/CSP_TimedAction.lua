-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches CSISTimedAction for Build 42.13.2+ compatibility
-- Original mod "Common Sense" by BitBraven. All credit to the author.
-- ====================================================================

if not CSISTimedAction then
    print("[DelFix] ERROR: CSISTimedAction not found. Is Common Sense loaded?")
    return
end

print("[DelFix] Patching CSISTimedAction for B42.13+ compatibility...")

require "TimedActions/ISBaseTimedAction"

-- ====================================================================
-- FIX 1: start() - Sound playback uses patched BB_CS_Utils
-- Added safety checks for nil self.character and self.priableObject
-- ====================================================================
CSISTimedAction.start = function(self)
    if not self.character then return end

    if self.typeTimeAction == "pryDoor" then
        self:setActionAnim("RemoveBarricade")
        self:setAnimVariable("RemoveBarricade", "CrowbarMid")
        if self.character:isTimedActionInstant() then return end

        BB_CS_Utils.DelayFunction(function()
            if self.character and self.priableObject then
                BB_CS_Utils.TryPlaySoundClip(self.character, BB_CS_Utils.GetProperSound(self.priableObject, false))
            end
        end, 35, true)
    end

    if self.typeTimeAction == "pryVehicleDoor" then
        self:setActionAnim("RemoveBarricade")
        self:setAnimVariable("RemoveBarricade", "CrowbarMid")
        if self.character:isTimedActionInstant() then return end

        BB_CS_Utils.DelayFunction(function()
            if self.character then
                BB_CS_Utils.TryPlaySoundClip(self.character, "MetalBarHit")
            end
        end, 35, true)
    end
end

-- ====================================================================
-- FIX 2: stop() - Add safety checks
-- ====================================================================
CSISTimedAction.stop = function(self)
    ISBaseTimedAction.stop(self)

    if not self.character then return end

    if self.typeTimeAction == "pryDoor" and self.priableObject then
        BB_CS_Utils.TryStopSoundClip(self.character, BB_CS_Utils.GetProperSound(self.priableObject, false))
    end

    if self.typeTimeAction == "pryVehicleDoor" then
        BB_CS_Utils.TryStopSoundClip(self.character, "MetalBarHit")
    end
end

-- ====================================================================
-- FIX 3: perform() - The core prying action, with safety fixes
-- ====================================================================
CSISTimedAction.perform = function(self)
    if not self.character then
        ISBaseTimedAction.perform(self)
        return
    end

    -- Track whether prying succeeded so TryReturnTool can be called
    -- AFTER ISBaseTimedAction.perform (see B42.14 fix comment below).
    local prySucceeded = false

    if self.typeTimeAction == "pryDoor" then
        BB_CS_Utils.TirePlayer(self.character, 0.07)

        if self.priableObject then
            BB_CS_Utils.TryStopSoundClip(self.character, BB_CS_Utils.GetProperSound(self.priableObject, false))
        end

        if CSUtils.PrySuccessfully(self.character, 0) == true then
            prySucceeded = true
            -- Use RequestPryDoorOpen for proper MP sync (sends to server in MP)
            if CSServer and CSServer.RequestPryDoorOpen then
                CSServer.RequestPryDoorOpen(self.worldObjects, self.priableObject, self.character)
            elseif CSServer and CSServer.PryDoorOpen then
                CSServer.PryDoorOpen(self.worldObjects, self.priableObject, self.character)
            end
        else
            self.character:Say(getText("IGUI_Pry_fail"))
            self.character:getXp():AddXP(Perks.Strength, 4)

            if self.priableObject and BB_CS_Utils.GetProperSound(self.priableObject, true) == "Wooden" then
                BB_CS_Utils.TryPlaySoundClip(self.character, "BreakLockOnWindow")
            else
                BB_CS_Utils.TryPlaySoundClip(self.character, "MetalBarBreak")
            end
        end
    end

    if self.typeTimeAction == "pryVehicleDoor" then
        BB_CS_Utils.TirePlayer(self.character, 0.1)
        BB_CS_Utils.TryStopSoundClip(self.character, "MetalBarHit")

        if CSUtils.PrySuccessfully(self.character, 20) == true then
            prySucceeded = true

            -- FIX: Use server command for MP sync (similar to door prying)
            if CSServer and CSServer.RequestPryVehicleDoorOpen then
                CSServer.RequestPryVehicleDoorOpen(self.vehicle, self.priableObject, self.character)
            else
                -- Fallback: local execution for old CS versions
                if self.priableObject and self.priableObject:getDoor() then
                    self.priableObject:getDoor():setLocked(false)
                    self.priableObject:getDoor():setOpen(true)

                    -- Mark lock as broken so the game's ISLockVehicleDoor won't re-lock it
                    if self.priableObject:getDoor().setLockBroken then
                        self.priableObject:getDoor():setLockBroken(true)
                    end
                end

                if self.vehicle then
                    self.vehicle:transmitPartDoor(self.priableObject)
                end
            end

            local isTrunk = self.priableObjectID == "TrunkDoor" or self.priableObjectID == "DoorRear"
            if not isTrunk then
                BB_CS_Utils.TryPlaySoundClip(self.character, "VehicleDoorOpen")
            else
                BB_CS_Utils.TryPlaySoundClip(self.character, "VehicleTrunkOpen")
            end

            self.character:getXp():AddXP(Perks.Strength, 10)
        else
            self.character:Say(getText("IGUI_Pry_fail"))
            BB_CS_Utils.TryPlaySoundClip(self.character, "MetalBarBreak")
            self.character:getXp():AddXP(Perks.Strength, 3)

            if SandboxVars.CommonSense and SandboxVars.CommonSense.ShatterVehicleWindows
                and SandboxVars.CommonSense.WindowShatterChance
                and ZombRand(100) <= SandboxVars.CommonSense.WindowShatterChance then
                if self.vehicle then
                    local part = self.vehicle:getClosestWindow(self.character)
                    if part then
                        local window = part:getWindow()
                        if window and not window:isOpen() then
                            if not window:isDestroyed() then
                                window:damage(window:getHealth())
                            end
                        end
                    end
                end
            end
        end
    end

    -- B42.14 FIX (Error #3): Call ISBaseTimedAction.perform BEFORE TryReturnTool.
    --
    -- Root cause: In B42.14, the Kahlua/Java bridge has a bug in ReturnValues.put
    -- where "callFrame" is null when StartAction is called on a newly-queued action.
    -- The crash chain is:
    --   perform(self) → ISTimedActionQueue.onCompleted → ISBaseTimedAction.begin → StartAction [CRASH]
    --
    -- If TryReturnTool runs first (adds ISInventoryTransferAction/ISUnequipAction to
    -- queue), then ISBaseTimedAction.perform finds those items and immediately tries
    -- to start them via StartAction → Java NullPointerException.
    --
    -- By calling ISBaseTimedAction.perform first (queue has no new items yet),
    -- onCompleted processes cleanly. TryReturnTool then adds its actions AFTER
    -- the queue chain is done — they get picked up normally on the next game tick
    -- without touching the broken StartAction call path.
    ISBaseTimedAction.perform(self)

    if prySucceeded then
        CSISTimedAction.TryReturnTool(self)
    end
end

-- ====================================================================
-- FIX 4: TryReturnTool - Add safety checks
-- ====================================================================
CSISTimedAction.TryReturnTool = function(self)
    if self.container == nil then return end
    if not self.character then return end

    local tool = self.character:getPrimaryHandItem()
    if not tool then return end

    local currentToolContainer = tool:getContainer()
    if not currentToolContainer then return end

    if self.container ~= currentToolContainer then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(self.character, tool, currentToolContainer, self.container))
    elseif tool:isEquipped() then
        ISTimedActionQueue.add(ISUnequipAction:new(self.character, tool, 50))
    end
end

print("[DelFix] CSISTimedAction patched successfully!")
