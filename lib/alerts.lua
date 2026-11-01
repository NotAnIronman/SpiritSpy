-- Watch for a stored spirit count dropping below the user's chosen threshold.
local Catalog = require("lib/catalog")
local M = {}

function M.new()
    local self = {}
    local previous, warned, signature = {}, {}, nil

    -- Forget previous counts when we change session or warning settings.
    function self:reset()
        previous, warned, signature = {}, {}, nil
    end

    -- Remember the starting count, then warn once per low spirit until it is refilled.
    function self:check(reader, settings)
        local currentSignature = tostring(settings.warningEnabled)
            .. ":"
            .. settings.warningThreshold
        if currentSignature ~= signature then
            self:reset()
            signature = currentSignature
        end
        if not settings.warningEnabled then
            return {}
        end
        local notices = {}

        -- Only watch spirits that fit a carried box. Missing readings are not treated as zero.
        for _, spirit in ipairs(Catalog.spirits) do
            local value = reader:canHold(spirit) and reader:count(spirit) or nil
            if Catalog.isCount(value) then
                local old = previous[spirit.id]
                if value >= settings.warningThreshold then
                    warned[spirit.id] = nil
                end
                if
                    old
                    and value < old
                    and value < settings.warningThreshold
                    and not warned[spirit.id]
                then
                    notices[#notices + 1] = Catalog.label(spirit, value, false)
                    warned[spirit.id] = true
                end
                previous[spirit.id] = value
            else
                previous[spirit.id] = nil
            end
        end
        return notices
    end

    return self
end

return M
