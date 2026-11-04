-- ====================================================================
-- Delirium-Fix: Common Sense - FixingManager.getFixes NPE Wrapper
--
-- Bug: FixingManager.getFixes() throws NullPointerException when a
-- fixing script has broken/unparsed Require lines (B41 colon syntax
-- instead of B42 equals syntax). This crashes the entire vehicle
-- mechanics context menu, preventing repairs.
--
-- Fix: Wrap FixingManager.getFixes to catch NPE and reimplement the
-- logic in Lua, filtering out broken entries so valid fixes still work.
-- ====================================================================

print("[DelFix] Loading FixingManager NPE protection...")

if not FixingManager then
    print("[DelFix]   FixingManager not found, skipping fixing wrapper.")
    return
end

-- Save the original Java function
local originalGetFixes = FixingManager.getFixes

-- Safe wrapper that catches NPE and filters broken entries
local function safeGetFixes(part)
    if not part then return nil end

    -- Try the original function first
    local success, result = pcall(originalGetFixes, part)

    -- NEW: If success is true, ALWAYS return the result (even if nil).
    -- Only go to fallback if the original function CRASHED (success == false).
    if success then
        return result
    end

    -- Original failed (NPE), reimplement in Lua
    print("[DelFix]   FixingManager.getFixes crashed for " .. tostring(part:getId()) .. ", using Lua fallback")

    -- Get all fixing definitions
    local allFixings = nil
    if FixingManager.getAllFixings then
        allFixings = FixingManager.getAllFixings()
    elseif getAllFixings then
        allFixings = getAllFixings()
    end
    
    if not allFixings then return ArrayList.new() end

    -- Filter to those that apply to this part
    local validFixes = ArrayList.new()
    local partItemType = part:getItemType() -- Get the item type needed for this part (e.g. "Base.Engine")

    for i = 0, allFixings:size() - 1 do
        local fixing = allFixings:get(i)
        if fixing then
            local fixingSuccess, fixingMatches = pcall(function()
                -- A fixing applies if its Required Item matches the part's item type
                local reqItem = fixing:getRequiredItem()
                if reqItem and partItemType and reqItem == partItemType then
                    return true
                end
                
                -- Fallback for some mods: check if Required Item matches part ID
                if reqItem and reqItem == part:getId() then
                    return true
                end
                
                return false
            end)

            if fixingSuccess and fixingMatches then
                -- This is a valid fixing entry
                validFixes:add(fixing)
            end
        end
    end

    return validFixes
end

-- Override FixingManager.getFixes with our safe version
FixingManager.getFixes = safeGetFixes

print("[DelFix] FixingManager NPE protection enabled.")
