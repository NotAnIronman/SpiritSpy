-- Show a short low-spirit popup and play the bundled chime when sound is enabled.
local M = {}

function M.new()
    local self = {}
    local root, parent, label, remaining, message = nil, nil, nil, 0, nil
    local sound, lastError, layout

    -- Remove the popup and stop any sound when the warning expires or the plugin closes.
    function self:clear()
        if root then
            pcall(function()
                root:Destroy()
            end)
        end
        if sound then
            pcall(function()
                sound:Stop()
            end)
        end
        root, parent, label, remaining, message, sound, layout = nil, nil, nil, 0, nil, nil, nil
    end

    -- Start an eight-second warning for the latest batch of low spirit counts.
    function self:show(lines, settings)
        if #lines == 0 then
            return
        end
        message = table.concat(lines, "<br>", 1, #lines)
        remaining = 8
        layout = nil

        -- Use the game's sound-effects channel, so the game volume settings still apply.
        if settings.warningSound then
            local ok, result = pcall(function()
                if sound then
                    sound:Stop()
                end
                local params = audio.SoundPlaybackParams.new()
                params.type, params.audioBus = audio.SoundType.SCRIPT, audio.AudioBus.SFX
                params.emitterShape, params.volume = audio.EmitterShape.NONE, 0.7
                params.numLoops, params.delayTick = 0, 0
                return audio.Play(Plugin.resources.warning, params)
            end)
            if ok and result then
                sound = result
            elseif not lastError then
                log(
                    "Spirit Spy could not play its warning sound. Check the installation and SFX volume."
                )
                lastError = true
            end
        end
    end

    -- Count down the popup and only show it while the game is available and focused.
    function self:draw(delta, focused)
        if not message then
            return
        end
        remaining = remaining - math.max(0, delta or 0)
        if remaining <= 0 then
            self:clear()
            return
        end
        if not focused or not Player.IsAvailable() then
            if root then
                root.hidden = true
            end
            return
        end
        local host = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
        if not host or not host.visibleGlobal then
            if root then
                root.hidden = true
            end
            return
        end

        -- Build a click-through popup under the current overlay layer.
        if parent ~= host then
            if root then
                pcall(function()
                    root:Destroy()
                end)
            end
            parent, layout = host, nil
            root = ui.Layer.new(host)
            root.clickthrough = true
            root:SetPos(0, 60, 0.5, 0, -0.5, 0)
            local background = ui.Rectangle.new(root)
            background:SetSize(0, 0, 1, 1)
            background.rgba, background.fill, background.clickthrough = 0x14202FEE, true, true
            label = ui.Text.new(root)
            label:SetPos(12, 10)
            label:SetSize(-24, -20, 1, 1)
            label.font, label.rgba, label.clickthrough =
                id.Font.MUSEO_SANS_15PT_REGULAR, 0xFFFFFFFF, true
            label.alignHorizontal = ui.AlignMode.CENTRE
            label.maxLines = 0
        end

        -- Fit the popup to the screen and only update its layout when the message or size changes.
        local width = math.max(120, math.min(380, host.width - 24))
        local _, breaks = message:gsub("<br>", "", math.maxinteger)
        local height = math.max(40, math.min(host.height - 72, 64 + breaks * 24))
        local key = width .. ":" .. height .. ":" .. message
        if layout ~= key then
            root:SetSize(width, height)
            label.content = "<col=FFD56AFF>Low spirits</col><br>" .. message
            layout = key
        end
        root.hidden = false
    end

    return self
end

return M
