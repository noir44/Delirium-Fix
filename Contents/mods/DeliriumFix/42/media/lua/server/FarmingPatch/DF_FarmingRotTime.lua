-- ====================================================================
-- Delirium-Fix: vanilla farming, longer last stage before rot.
--
-- The last stage (seed-bearing, still harvestable) lasts prop.rotTime
-- game hours, or timeToGrow/2 when a crop has none; then the plant rots
-- (farming_vegetableconf.grow, branch nbOfGrow == prop.fullGrown). With
-- 16 game days per real day that is 13-45 real hours, and gardens rot
-- while their owners are offline.
--
-- Sandbox DelFix.FarmingRotTimeMultiplier multiplies that time. It is
-- applied only when a plant enters the last stage: plants already there
-- keep the deadline they got (vanilla stores it in planting.nextGrowing).
-- Growth stages, yield and anything else are untouched.
-- ====================================================================

if isClient() then return end

local DEFAULT_MULT = 10

-- Original rotTime of each crop, as the crop defined it (nil = none).
local baseRot = {}
local seen = {}

local function rotMultiplier()
    local opts = SandboxVars.DelFix
    local v = opts and tonumber(opts.FarmingRotTimeMultiplier)
    if not v or v < 1 then return DEFAULT_MULT end
    return v
end

local function install()
    if type(farming_vegetableconf) ~= "table" or type(farming_vegetableconf.grow) ~= "function" then
        return false
    end
    if farming_vegetableconf.DelFixRotWrapped then return true end
    farming_vegetableconf.DelFixRotWrapped = true

    local origGrow = farming_vegetableconf.grow
    farming_vegetableconf.grow = function(planting, nextGrowing, updateNbOfGrow)
        local props = farming_vegetableconf.props
        local prop = planting and props and props[planting.typeOfSeed]
        if not prop or not prop.fullGrown or not prop.timeToGrow
                or planting.nbOfGrow ~= prop.fullGrown then
            return origGrow(planting, nextGrowing, updateNbOfGrow)
        end
        local seed = planting.typeOfSeed
        if not seen[seed] then
            seen[seed] = true
            baseRot[seed] = prop.rotTime
        end
        local base = baseRot[seed] or math.floor(prop.timeToGrow / 2)
        -- Set for this one call and put back, so nothing else sees a changed
        -- prop; recomputed from baseRot every time, so it can never compound.
        prop.rotTime = base * rotMultiplier()
        local result = origGrow(planting, nextGrowing, updateNbOfGrow)
        prop.rotTime = baseRot[seed]
        return result
    end
    print("[DelFix] farming: last stage before rot multiplied by sandbox FarmingRotTimeMultiplier")
    return true
end

-- Vanilla server/Farming may load after this file; then wrap once the
-- world is up (SFarmingSystem looks the function up on every call).
if not install() then
    Events.OnInitGlobalModData.Add(install)
end
