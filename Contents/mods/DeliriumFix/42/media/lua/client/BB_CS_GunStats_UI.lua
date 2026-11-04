-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Override for BB_CS_GunStats_UI.lua
-- Original mod "Common Sense" by BitBraven. All credit to the author.
--
-- In B42.13+, Type.Normal may not exist, causing a nil call crash
-- in fetchAllAmmoTypes(). This replacement safely handles the check
-- and also protects against other potential nil issues.
-- ====================================================================

local compatify = false
local exceptionIDs = { "Advanced_trajectory", "TheStar", "Arsenal(26)GunFighter", "Arsenal(26)GunFighter[MAIN MOD 2.0]" }
local ammoTexture = getTexture("Item_PistolAmmo")
local UIAssets = {}
local UIVisible = true
local ammoList = {}
local ammoWordBlacklist = {
    "Box",
    "Carton",
    "Clip",
    "Mold",
}

local function setAssetState(newState)
    for _, asset in ipairs(UIAssets) do
        asset:setVisible(newState)
    end

    UIVisible = newState
end

local function updateAmmoTexture(gun)
    if not UIAssets[1] then return end

    local ammoType = gun:getAmmoType() or ""
    UIAssets[1].texture = nil

    for _, ammo in ipairs(ammoList) do
        if ammo.type == ammoType then
            UIAssets[1].texture = ammo.texture
            break
        end
    end

    if UIAssets[1].texture == nil then
        UIAssets[1].texture = ammoTexture
    end
end

local function updateAmmoStyle(gun)
    if not UIAssets[2] then return end

    local ammoCount = gun:getCurrentAmmoCount() or 0
    if gun:isRoundChambered() then ammoCount = ammoCount + 1 end
    UIAssets[2].name = tostring(ammoCount)

    local maxAmmoCount = gun:getMaxAmmo() or 0
    local ammoPercentage = ammoCount / maxAmmoCount

    if ammoPercentage > 0.5 then
        UIAssets[2].r = 1
        UIAssets[2].g = 1
        UIAssets[2].b = 1
    elseif ammoPercentage > 0.25 then
        UIAssets[2].r = 1
        UIAssets[2].g = 1
        UIAssets[2].b = 0
    elseif ammoPercentage > 0 then
        UIAssets[2].r = 1
        UIAssets[2].g = 0
        UIAssets[2].b = 0
    else
        UIAssets[2].r = 0.7
        UIAssets[2].g = 0
        UIAssets[2].b = 0
    end
end

local leftUIBarRender = ISEquippedItem.render

function ISEquippedItem:render()
    leftUIBarRender(self)
    if not SandboxVars.CommonSense then return end
    if not SandboxVars.CommonSense.GunStats then return end
    if compatify then return end
    if #UIAssets < 2 then return end

    local primaryItem = self.chr:getPrimaryHandItem()
    if primaryItem and primaryItem:IsWeapon() and primaryItem:isRanged() and primaryItem:getAmmoType() then

        updateAmmoTexture(primaryItem)
        updateAmmoStyle(primaryItem)

        if not UIVisible then
            setAssetState(true)
        end

    elseif UIVisible then
        setAssetState(false)
    end
end

local leftUIBarInit = ISEquippedItem.initialise

function ISEquippedItem:initialise()

	local menu = leftUIBarInit(self)

    if SandboxVars.CommonSense and SandboxVars.CommonSense.GunStats and not compatify then
        local scaleFactor = 3
        local alpha = 0.5

        local ammoImage = ISImage:new(
        self.mainHand:getX() + 48,
        self.mainHand:getY() + 8,
        self.mainHand:getWidth() / scaleFactor,
        self.mainHand:getHeight() / scaleFactor,
        nil)

        ammoImage.backgroundColor = { r = 1, g = 1, b = 1, a = alpha }
        ammoImage:initialise()
        ammoImage.parent = self
        self:addChild(ammoImage)
        table.insert(UIAssets, ammoImage)

        local ammoText = ISLabel:new(ammoImage:getX() + 40, ammoImage:getY() - 16, 64, "", 1, 1, 1, alpha, UIFont.Medium, true)
        ammoText:initialise()
        ammoText.parent = self
        self:addChild(ammoText)
        table.insert(UIAssets, ammoText)

        local primaryItem = getPlayer():getPrimaryHandItem()
        if primaryItem and primaryItem:IsWeapon() and primaryItem:isRanged() and primaryItem:getAmmoType() then
            updateAmmoTexture(primaryItem)
        end
    end

	return menu
end

-- ====================================================================
-- PATCHED: fetchAllAmmoTypes
-- Original uses Type.Normal which doesn't exist in B42.13+
-- In B42.14, KahluaTableImpl changed how tables with a "Type" field behave:
-- `Type` now exists as a special Java-backed table, making `Type.Normal`
-- potentially throw a Java exception (not catchable by pcall in all cases).
-- Fix: skip the Type.Normal check entirely, it was already just a safety
-- guard. The "Ammo" DisplayCategory check is sufficient.
-- ====================================================================
local function fetchAllAmmoTypes()
    local allScriptItems = getScriptManager():getAllItems()
    if not allScriptItems then return end

    for i = 1, allScriptItems:size() do
        local scriptItem = allScriptItems:get(i - 1)
        if scriptItem then
            local itemName = scriptItem:getFullName()

            -- B42.14 FIX: Skip Type.Normal check entirely.
            -- In B42.14, `Type` is a special Kahlua-backed table and accessing
            -- `Type.Normal` can throw uncatchable Java exceptions. Since we
            -- already filter by DisplayCategory == "Ammo" below, this check
            -- is redundant and safe to skip.
            local isNormalType = true

            local isAmmo = false
            local success2, result2 = pcall(function()
                return scriptItem:getDisplayCategory() == "Ammo"
            end)
            if success2 then
                isAmmo = result2
            end

            if isNormalType and isAmmo then
                local invalid = false
                for _, blockedWord in ipairs(ammoWordBlacklist) do
                    if itemName and string.find(itemName, blockedWord) then
                        invalid = true
                    end
                end

                if not invalid then
                    local texture = nil
                    pcall(function()
                        local textureData = scriptItem:getNormalTexture()
                        if textureData then
                            local texName = textureData.name or ""
                            if texName then
                                local textureString = tostring(textureData)
                                local pattern = 'name:"(.*)"'
                                local match = string.match(textureString, pattern)
                                if match then
                                    texName = match:sub(1, -1)
                                end
                            end
                            texture = getTexture(texName)
                        end
                    end)

                    local ammo = { type = itemName, texture = texture }
                    table.insert(ammoList, ammo)
                end
            end
        end
    end
end

local function onEarliestStart()
    if not SandboxVars.CommonSense then return end
    if not SandboxVars.CommonSense.GunStats then return end
    if compatify then return end

    local activatedMods = getActivatedMods()
    if activatedMods then
        for _, modID in ipairs(exceptionIDs) do
            if activatedMods:contains(modID) then
                compatify = true
                return
            end
        end
    end

    local success, err = pcall(fetchAllAmmoTypes)
    if not success then
        print("[DelFix] Warning: fetchAllAmmoTypes failed: " .. tostring(err))
    end
end

Events.OnInitGlobalModData.Add(onEarliestStart)
