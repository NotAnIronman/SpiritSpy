-- Update the client's existing hover box, including its width, instead of drawing a second one.
local Catalog = require("lib/catalog")
local M = {}

-- Keep the original size values so we can put the native box back exactly as it was.
local function sizeOf(component)
    local size = component.size
    return { size.width, size.height, size.widthParentPc, size.heightParentPc }
end

local function restoreSize(component, size)
    component:SetSize(size[1], size[2], size[3], size[4])
end

local function sameSize(component, size)
    if not size then
        return false
    end
    local current = sizeOf(component)
    for i = 1, 4 do
        if current[i] ~= size[i] then
            return false
        end
    end
    return true
end

local function setSize(component, size)
    if not sameSize(component, size) then
        restoreSize(component, size)
    end
end

function M.new()
    local self = {}
    local name, suffix, applied, lastError

    -- Only undo text and sizes that still match our changes.
    local function restore()
        if applied then
            pcall(function()
                if applied.label.content == applied.rendered then
                    applied.label.content = applied.original
                end
                if sameSize(applied.box, applied.renderedBoxSize) then
                    restoreSize(applied.box, applied.boxSize)
                end
                if sameSize(applied.label, applied.renderedLabelSize) then
                    restoreSize(applied.label, applied.labelSize)
                end
            end)
            applied = nil
        end
    end

    -- Forget the old target and restore its hover box.
    function self:clear()
        name, suffix = nil, nil
        restore()
    end

    -- Remember the target name and the extra text we want beside it.
    function self:setTarget(targetName, countSuffix)
        if not targetName then
            self:clear()
            return
        end
        name, suffix = Catalog.normalise(targetName), countSuffix
    end

    -- Find the live hover label, check its target, then add our text and make room for it.
    function self:draw()
        if not name then
            return
        end
        local ok, err = pcall(function()
            local label = ui.Interfaces:GetComponent(id.Interface.TOPLEVEL_V2, 902, 0, 0)
            if not label then
                restore()
                return
            end
            if label.type ~= ui.ComponentType.LABEL then
                restore()
                return
            end
            if not label.visibleGlobal then
                restore()
                return
            end
            -- The label sits inside several layers. Grow frame 899 and its inner layers follow.
            local box = ui.Interfaces:GetComponent(id.Interface.TOPLEVEL_V2, 899)
            local ancestor, insideFrame, parentGrowth = label.parent, false, 1
            for _ = 1, 8 do
                if not ancestor then
                    break
                end
                if ancestor.staticID == 899 then
                    insideFrame = true
                    break
                end
                parentGrowth = parentGrowth * ancestor.size.widthParentPc
                ancestor = ancestor.parent
            end
            if not box or box.type ~= ui.ComponentType.LAYER or not insideFrame then
                restore()
                return
            end
            if applied and (applied.label ~= label or applied.box ~= box) then
                restore()
            end
            local current = label.content
            local original = applied and current == applied.rendered and applied.original or current
            local plain = Catalog.normalise(original)
            local first, last = plain:find(name, 1, true)
            if
                not first
                or (first > 1 and plain:sub(first - 1, first - 1):match("[%w]", 1))
                or plain:sub(last + 1, last + 1):match("[%w]", 1)
            then
                restore()
                return
            end

            -- Measure the extra text and grow the original box without adding the width twice.
            local rendered = original .. suffix
            if not applied or (current ~= applied.rendered and current ~= applied.original) then
                restore()
                applied = {
                    original = original,
                    labelSize = sizeOf(label),
                    boxSize = sizeOf(box),
                    parentGrowth = parentGrowth,
                }
            end
            applied.label, applied.box, applied.rendered = label, box, rendered
            local font = config.Font.FromID(label.font)
            local extraWidth = math.max(
                0,
                font:GetStringWidth(rendered, false) - font:GetStringWidth(original, false)
            )
            label.content = rendered
            local boxSize, labelSize = applied.boxSize, applied.labelSize
            applied.renderedBoxSize =
                { boxSize[1] + extraWidth, boxSize[2], boxSize[3], boxSize[4] }
            setSize(box, applied.renderedBoxSize)
            -- Relative labels already inherit some of the frame's extra width.
            -- Account for that here, since the client may lay them out after Draw.
            local inheritedWidth = extraWidth * applied.parentGrowth * labelSize[3]
            applied.renderedLabelSize = {
                math.ceil(labelSize[1] + extraWidth - inheritedWidth),
                labelSize[2],
                labelSize[3],
                labelSize[4],
            }
            setSize(label, applied.renderedLabelSize)
        end)
        if not ok then
            restore()
            if tostring(err) ~= lastError then
                log("Spirit Spy could not update the native hover box: " .. tostring(err))
                lastError = tostring(err)
            end
        else
            lastError = nil
        end
    end

    return self
end

return M
