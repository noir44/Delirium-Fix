-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches BB_CS_ParamMods for Build 42.13.2+ compatibility
-- Original mod "Common Sense" by BitBraven. All credit to the author.
-- ====================================================================

print("[DelFix] Patching ParamMods for B42.13+ compatibility...")

require "OptionScreens/CharacterCreationProfession"

-- ====================================================================
-- FIX: ScriptManager.instance:getItem() may behave differently in B42.13
-- Some items may not exist or DoParam may fail.
-- Wrap everything in pcall for safety.
-- ====================================================================

-- Safe DoParam wrapper
local function safeDoParam(itemId, param)
    local success = pcall(function()
        local item = ScriptManager.instance:getItem(itemId)
        if item then
            item:DoParam(param)
        end
    end)
    if not success then
        print("[DelFix] Warning: Could not apply param '" .. param .. "' to " .. itemId)
    end
end

-- Re-apply the param mods safely
safeDoParam("Base.BathTowel", "UseDelta = 0.03")
safeDoParam("Base.DishCloth", "UseDelta = 0.05")

-- Flashlight attachment fix (safe version)
pcall(function()
    local exceptionIDs = { "shine_together", "noirrsling", "nattachments" }
    local flashlightIDs = { "Base.HandTorch", "Base.Flashlight_Crafted" }

    local activatedMods = getActivatedMods()
    local compatify = false

    if activatedMods then
        for _, modID in ipairs(exceptionIDs) do
            if activatedMods:contains(modID) then
                compatify = true
                break
            end
        end
    end

    if not compatify then
        for _, flashlightID in ipairs(flashlightIDs) do
            safeDoParam(flashlightID, "AttachmentType = Screwdriver")
        end
    end
end)

pcall(function()
    local originalIsTraitEnabled = CharacterCreationProfession.isTraitEnabled
    if not originalIsTraitEnabled then
        return
    end

    function CharacterCreationProfession:isTraitEnabled(trait)
        local traitType = trait and trait:getType()
        if traitType == CharacterTrait.INSOMNIAC
            or traitType == CharacterTrait.NEEDS_LESS_SLEEP
            or traitType == CharacterTrait.NEEDS_MORE_SLEEP then
            return true
        end

        return originalIsTraitEnabled(self, trait)
    end
end)

print("[DelFix] ParamMods patched successfully!")
