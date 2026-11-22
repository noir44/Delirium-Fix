-- ====================================================================
-- Delirium-Fix: Ammo Maker (ammomaker, Workshop 2788256295)
--
-- 1. Sandbox DelFix.AmmoMakerDropCasings (default off): casings from
--    shots are not put on the ground. Ammo Maker routes every casing that
--    goes to the ground through its global ammoMakerAddItemToWorld(square,
--    item, true); the third argument (auto-removal) is true only for
--    casings, entity leftovers pass false. Brass catchers and inventory
--    returns use another function and keep working.
--
-- 2. Stale clean-up records. Ammo Maker remembers every dropped casing in
--    global ModData and removes a record only when its square is loaded
--    and the casing is still there. Casings that were picked up, or lie
--    where nobody comes, leave records forever (6798 on the main server,
--    2026-11-22). Records older than the casing lifetime are such leftovers
--    and are dropped here; younger ones stay, so Ammo Maker still removes
--    the casings that are on the ground now.
--
-- Does nothing when Ammo Maker is not loaded.
-- ====================================================================

if isClient() then return end
if type(ammoMakerAddItemToWorld) ~= "function" then return end

local RECORD_KEYS = { "ammoMakerDroppedCasings", "droppedCasings" }

local function dropAllowed()
    local opts = SandboxVars.DelFix
    return opts ~= nil and opts.AmmoMakerDropCasings == true
end

local originalAddItemToWorld = ammoMakerAddItemToWorld

ammoMakerAddItemToWorld = function(square, itemInstance, autoRemoval)
    if autoRemoval == true and not dropAllowed() then return end
    return originalAddItemToWorld(square, itemInstance, autoRemoval)
end

-- Record format: "<item type>;<x>;<y>;<z>;<world age days at drop>"
local function recordDropDay(record)
    if type(record) ~= "string" then return nil end
    local day = string.match(record, ";([%d%.]+)$")
    return day and tonumber(day) or nil
end

local function purgeStaleRecords()
    local amOpts = SandboxVars.ammomakerOptions
    local lifetimeHours = amOpts and tonumber(amOpts.DroppedCasingsLifetime) or 168
    local now = getWorld():getWorldAgeDays()

    for _, key in ipairs(RECORD_KEYS) do
        local records = ModData.get(key)
        if type(records) == "table" then
            local kept, removed = {}, 0
            for _, record in pairs(records) do
                local day = recordDropDay(record)
                if day and (lifetimeHours == 0 or now - day > lifetimeHours / 24) then
                    removed = removed + 1
                else
                    kept[#kept + 1] = record
                end
            end
            if removed > 0 then
                ModData.add(key, kept)
                print("[DelFix] Ammo Maker: removed " .. removed .. " stale casing records from " .. key .. ", kept " .. #kept)
            end
        end
    end
end

Events.EveryTenMinutes.Add(purgeStaleRecords)
print("[DelFix] Ammo Maker casing patch loaded")
