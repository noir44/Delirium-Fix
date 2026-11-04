-- ====================================================================
-- Delirium-Fix: Common Sense - Auto Rack After Reload
-- Automatically chambers a round after reloading, so the player does
-- not have to rack the slide by hand.
-- ====================================================================

-- Function to perform auto-rack
local function autoRackWeapon(character, weapon)
    if not weapon or not character then return end

    -- Auto-rack if weapon has ammo and is NOT already chambered
    local currentAmmo = weapon:getCurrentAmmoCount() or 0
    if currentAmmo > 0 and not weapon:isRoundChambered() then
        weapon:setRoundChambered(true)

        local rackSound = weapon:getRackSound()
        if rackSound then
            character:playSound(rackSound)
        end
    end
end

-- Last seen ammo count of the weapon in hand, to detect a finished reload
local lastWeapon = nil
local lastAmmo = 0

local function onPlayerUpdate(player)
    local weapon = player:getPrimaryHandItem()
    if not weapon or not weapon.getCurrentAmmoCount then
        lastWeapon = nil
        return
    end

    local currentAmmo = weapon:getCurrentAmmoCount() or 0
    if weapon ~= lastWeapon then
        lastWeapon = weapon
        lastAmmo = currentAmmo
        return
    end

    -- Reload finished: ammo increased since last check
    if currentAmmo > lastAmmo and currentAmmo > 0 then
        autoRackWeapon(player, weapon)
    end
    lastAmmo = currentAmmo
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
