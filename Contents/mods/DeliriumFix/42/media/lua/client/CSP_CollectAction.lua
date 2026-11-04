-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches BB_Collect_TA for Build 42.13+ MP compatibility
-- Original mod "Common Sense" by BitBraven. All credit to the author.
--
-- FIX: The "Obvious Collecting" feature (picking up rocks, twigs, trash
-- from ground sprites) adds items on the CLIENT side using
-- playerInv:AddItem(). In Multiplayer, items added from the client
-- may not sync properly to the server, causing items to be "stuck"
-- in inventory (can't move or drop them).
--
-- Solution: In MP, send a "CollectItems" command to the server so
-- items are added on the server-side and properly synced.
-- ====================================================================

if not BB_Collect_TA then
    print("[DelFix] BB_Collect_TA not found, skipping collect action patch.")
    return
end

print("[DelFix] Patching BB_Collect_TA for B42.13+ MP compatibility...")

-- Save the original perform function
local originalPerform = BB_Collect_TA.perform

BB_Collect_TA.perform = function(self)
    if not self then
        if originalPerform then originalPerform(self) end
        return
    end

    if self.typeTimeAction == "Collect" then

        -- Stop sound
        if self.playerObj and self.spriteName then
            if string.find(self.spriteName, "trash") then
                BB_CS_Utils.TryStopSoundClip(self.playerObj, "FoleyTrash")
            else
                BB_CS_Utils.TryStopSoundClip(self.playerObj, "FoleyForage")
            end
        end

        -- Add items: use different paths for SP vs MP
        if not SandboxVars.CommonSense.DisableLoot then
            local lootMultiplier = SandboxVars.CommonSense.LootMultiplier or 1

            if isClient() then
                -- MULTIPLAYER: Send to server for proper item sync
                local args = {
                    itemsList = self.itemsList or "",
                    lootMultiplier = lootMultiplier,
                }
                sendClientCommand(self.character, "DelFix", "CollectItems", args)
            else
                -- SINGLE PLAYER: Add items directly (original behavior)
                local playerInv = self.playerObj:getInventory()
                if playerInv and self.itemsList then
                    for item in string.gmatch(self.itemsList, "([^,]+)") do
                        local itemName, itemCount = item:match("^(.+):(%d+)$")
                        if itemName and itemCount then
                            local count = math.floor(tonumber(itemCount) * lootMultiplier)
                            for i = 1, count do
                                playerInv:AddItem(itemName)
                            end
                        end
                    end
                end
            end
        end

        -- Remove the world sprite (this already uses sendClientCommand)
        if self.clickedSquare and self.spriteName then
            local args = {
                square = {
                    x = self.clickedSquare:getX(),
                    y = self.clickedSquare:getY(),
                    z = self.clickedSquare:getZ()
                },
                spriteName = self.spriteName
            }
            sendClientCommand(self.character, "CommonSense", "RemoveResources", args)
        end

        -- Always call base perform for this replaced action
        ISBaseTimedAction.perform(self)
    else
        if originalPerform then originalPerform(self) end
    end
end

-- Also patch the start function for safety
local originalStart = BB_Collect_TA.start
BB_Collect_TA.start = function(self)
    if not self then return end

    if self.typeTimeAction == "Collect" then
        self:setActionAnim("Loot")
        self:setAnimVariable("LootPosition", "Low")

        if self.playerObj and self.spriteName then
            if string.find(self.spriteName, "trash") then
                BB_CS_Utils.TryPlaySoundClip(self.playerObj, "FoleyTrash")
            else
                BB_CS_Utils.TryPlaySoundClip(self.playerObj, "FoleyForage")
            end
        end
    else
        if originalStart then originalStart(self) end
    end
end

print("[DelFix] BB_Collect_TA patched successfully! (MP item sync enabled)")
