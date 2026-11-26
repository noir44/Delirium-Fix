-- ====================================================================
-- Delirium-Fix: player corpses fit into containers again
--
-- A corpse becomes an item when it is picked up (ISGrabCorpseAction) or
-- put into a container such as a car trunk (ISDropCorpseIntoContainer ->
-- server Commands.deadBody.addBody -> becomeCorpseItem). The engine writes
-- the whole body into one fixed buffer of 20000 bytes
-- (InventoryItem.storeInByteData), and a corpse carries a copy of the
-- character's modData (IsoDeadBody constructor copies it). Mods that keep
-- large lists in player modData - Lifestyle stores every learned song as a
-- table in <Instrument>LearnedTracks, hundreds of them - overflow the buffer:
-- BufferOverflowException in the server log, the item is cut short and the
-- body vanishes until relog. Zombie corpses are small and never hit it.
--
-- Before either action, if the corpse's modData is estimated above
-- MODDATA_BUDGET bytes, its largest tables are dropped until it fits.
-- Only the corpse's own copy is touched; the living character never is,
-- and none of the server's mods reads modData from corpses (checked
-- 2026-11-26). Each cut is printed with key names, server and client side.
--
-- Clothes and inventory share the same buffer: a corpse with packed
-- pockets can still overflow, empty them first.
-- ====================================================================

require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISGrabCorpseAction"
require "TimedActions/ISDropCorpseIntoContainer"

-- Rest of the 20000 bytes goes to visuals, worn items and inventory.
local MODDATA_BUDGET = 4000
local MAX_DEPTH = 20

-- Rough size in the KahluaTable save format: a type byte per value,
-- 2-byte length + characters for strings (doubled to cover UTF-8),
-- 8 bytes per number, an end marker per table. Overestimates on purpose.
local function valueSize(v, depth)
    local t = type(v)
    if t == "string" then return 3 + #v * 2 end
    if t == "number" then return 9 end
    if t == "boolean" then return 2 end
    if t == "table" then
        if depth > MAX_DEPTH then return 2 end
        local size = 2
        for k, val in pairs(v) do
            size = size + valueSize(k, depth + 1) + valueSize(val, depth + 1)
        end
        return size
    end
    return 2
end

local function shrinkModData(obj, source)
    if not obj or not instanceof(obj, "IsoObject") then return end
    local md = obj:getModData()
    if type(md) ~= "table" then return end

    local total = 2
    local tables = {}
    for k, v in pairs(md) do
        local size = valueSize(k, 1) + valueSize(v, 1)
        total = total + size
        if type(v) == "table" then
            tables[#tables + 1] = { key = k, size = size }
        end
    end
    if total <= MODDATA_BUDGET then return end

    table.sort(tables, function(a, b) return a.size > b.size end)
    local removed = {}
    for _, entry in ipairs(tables) do
        if total <= MODDATA_BUDGET then break end
        md[entry.key] = nil
        total = total - entry.size
        removed[#removed + 1] = tostring(entry.key) .. "=" .. entry.size
    end
    print("[DelFix] corpse modData cut before " .. source .. " (server=" .. tostring(isServer())
        .. "): " .. table.concat(removed, ", ") .. "; left ~" .. total .. " bytes")
end

-- Picking a corpse up: new() runs on the client and again on the server
-- (NetTimedAction), and calls corpseBody:getItem() right away.
local originalGrabNew = ISGrabCorpseAction.new
ISGrabCorpseAction.new = function(self, character, corpseBody, ...)
    shrinkModData(corpseBody, "grab")
    return originalGrabNew(self, character, corpseBody, ...)
end

-- Dropping a dragged corpse into a container: the dragged character
-- becomes a corpse item in perform() (client) and in the server's addBody
-- command, which takes the character cached by complete().
local originalDropNew = ISDropCorpseIntoContainer.new
ISDropCorpseIntoContainer.new = function(self, character, targetContainer, ...)
    local o = originalDropNew(self, character, targetContainer, ...)
    if o then shrinkModData(o.grappledChar, "container") end
    return o
end

local originalDropComplete = ISDropCorpseIntoContainer.complete
ISDropCorpseIntoContainer.complete = function(self, ...)
    shrinkModData(self.grappledChar, "container")
    return originalDropComplete(self, ...)
end
