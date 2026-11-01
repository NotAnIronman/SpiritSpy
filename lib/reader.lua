-- Read shared spirit storage and check which boxes the player is carrying.
local Catalog = require("lib/catalog")
local M = {}

local function try(fn)
    local ok, value = pcall(fn)
    if ok then
        return value
    end
end

function M.new(api)
    local self = {}
    local backpackDirty, carriedTiers = true, {}
    local woodDirty, woodCounts = true, nil

    -- Only reread cached inventories when a relevant inventory changes.
    function self:inventoryChanged(cfg)
        if cfg and cfg.id == api.backpackID then
            backpackDirty, woodDirty = true, true
        end
        if cfg and cfg.id == api.woodboxID then
            woodDirty = true
        end
    end

    -- Discard the previous character's box and storage readings.
    function self:reset()
        backpackDirty, carriedTiers = true, {}
        woodDirty, woodCounts = true, nil
    end

    -- Find the highest carried box of each kind. Banked and noted boxes do not count.
    function self:hasBox(kind)
        kind = kind or "stone"
        if not api.available() then
            self:reset()
            return false
        end
        if not backpackDirty then
            return carriedTiers[kind] ~= nil
        end
        carriedTiers = {}
        local slots = try(function()
            return api.slots(api.backpackID)
        end)
        if not slots then
            return false
        end
        for _, slot in pairs(slots) do
            if slot.obj and Catalog.isCount(slot.count) and slot.count > 0 then
                for boxKind, boxes in pairs(Catalog.boxes) do
                    local tier = boxes[slot.obj.id]
                    if tier then
                        carriedTiers[boxKind] = math.max(carriedTiers[boxKind] or 0, tier)
                    end
                end
            end
        end
        backpackDirty = false
        return carriedTiers[kind] ~= nil
    end

    -- Check whether a carried box is high enough for this spirit.
    function self:canHold(spirit)
        return self:hasBox(spirit.kind) and carriedTiers[spirit.kind] >= spirit.boxTier
    end

    -- Read wood spirits from box slots, or stone spirits from their named ore-box fields.
    function self:count(spirit)
        if spirit.kind == "wood" then
            if woodDirty then
                woodCounts = nil
                local slots = try(function()
                    return api.slots(api.woodboxID)
                end)
                if not slots then
                    return nil
                end
                local counts = {}
                for _, slot in pairs(slots) do
                    local item = slot.obj and Catalog.item(slot.obj.id)
                    if item and item.kind == "wood" then
                        if Catalog.isCount(slot.count) and counts[item.id] ~= false then
                            counts[item.id] = (counts[item.id] or 0) + slot.count
                        else
                            counts[item.id] = false
                        end
                    end
                end
                woodCounts, woodDirty = counts, false
            end
            local count = woodCounts and woodCounts[spirit.id]
            if count ~= nil and not Catalog.isCount(count) then
                return nil
            end
            return count or 0
        end

        -- If the named field is missing, only use an ID fallback when its name still agrees.
        local cfg = try(function()
            return api.variableByName(spirit.varName)
        end)
        if not cfg then
            cfg = try(function()
                local candidate = api.variableByID(spirit.varID)
                if candidate and candidate.configName == spirit.varName then
                    return candidate
                end
            end)
        end
        local value = cfg and try(function()
            return cfg.value
        end)
        if Catalog.isCount(value) then
            return value
        end
    end

    return self
end

return M
