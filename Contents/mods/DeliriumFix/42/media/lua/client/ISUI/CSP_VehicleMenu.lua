-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- Patches BB_CS_VehicleMenu for Build 42.13+ compatibility
-- Original mod "Common Sense" by BitBraven. All credit to the author.
-- ====================================================================

if not ISVehicleMenu or not ISVehicleMenu.showRadialMenuOutside then return end

local csShowRadialMenuOutside = ISVehicleMenu.showRadialMenuOutside

ISVehicleMenu.showRadialMenuOutside = function(playerObj)
    if not playerObj then return end
    
    -- Call CS's implementation safely (adds base menu + CS pry option)
    pcall(csShowRadialMenuOutside, playerObj)
end

print("[DelFix] Vehicle Menu patched (Duct Tape feature removed).")
