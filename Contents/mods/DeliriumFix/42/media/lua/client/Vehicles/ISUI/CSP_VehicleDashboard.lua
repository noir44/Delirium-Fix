-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- FIXES CS_ISVehicleDashboard crashes in Build 42.13+
-- Original mod "Common Sense" by BitBraven. All credit to the author.
--
-- PROBLEM: CS overrides ISVehicleDashboard:prerender to add a cosmetic
-- color overlay. In B42.13+ this crashes every frame because textures
-- don't exist, blocking the vehicle mechanics menu entirely.
--
-- SOLUTION: Detect if CS's version is present and wrap it in crash
-- protection. Also handle potential upvalue differences.
-- ====================================================================

if not ISVehicleDashboard then
    print("[DelFix] ISVehicleDashboard not found, skipping dashboard patch.")
    return
end

print("[DelFix] Checking Vehicle Dashboard for CS crash fix...")

local currentPrerender = ISVehicleDashboard.prerender
if not currentPrerender then
    print("[DelFix]   ISVehicleDashboard.prerender not found, skipping.")
    return
end

-- Check if this is CS's version by looking for the upvalue signature
local isCSVersion = false
local originalPrerender = nil

if debug and debug.getupvalue then
    for i = 1, 20 do
        local name, value = debug.getupvalue(currentPrerender, i)
        if not name then break end
        -- CS's version has "OnVehicleDashboardPreRender" upvalue
        if (name == "OnVehicleDashboardPreRender" or name == "OnVehicleDashboardPrerender") and type(value) == "function" then
            isCSVersion = true
            originalPrerender = value
            break
        end
    end
end

if not isCSVersion then
    -- Fallback: Check if the function name itself is a hint or just wrap it anyway
    -- to prevent any dashboard crashes from breaking the mechanics menu.
    print("[DelFix]   CS dashboard signature not detected, but wrapping prerender for safety.")
    originalPrerender = currentPrerender
end

-- Apply crash protection
local csPrerender = currentPrerender
local crashDetected = false

ISVehicleDashboard.prerender = function(self)
    if crashDetected then
        if originalPrerender then pcall(originalPrerender, self) end
        return
    end

    local success, err = pcall(csPrerender, self)
    if not success then
        print("[DelFix] ERROR: Vehicle dashboard crashed: " .. tostring(err))
        print("[DelFix] Disabling dashboard override to restore mechanics menu.")
        crashDetected = true
        if originalPrerender then pcall(originalPrerender, self) end
    end
end

print("[DelFix] Vehicle Dashboard protection enabled.")
