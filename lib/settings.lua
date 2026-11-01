-- Load the saved hover options, warning threshold and sound toggle.
local M = {}

function M.new(database, changed, preview)
    local self = {
        showHoverCount = database:GetBool("showHoverCount") ~= false,
        numberOnly = database:GetBool("numberOnly") == true,
        limitToBoxTier = database:GetBool("limitToBoxTier") == true,
        warningEnabled = database:GetBool("warningEnabled") ~= false,
        warningSound = database:GetBool("warningSound") ~= false,
        warningThreshold = math.max(
            1,
            math.min(2147483647, database:GetInt("warningThreshold") or 50)
        ),
    }
    local root

    -- Remove the previous settings view before replacing it.
    function self:clear()
        if root then
            pcall(function()
                root:Destroy()
            end)
        end
        root = nil
    end

    -- Build the hover and warning controls on the settings panel.
    function self:build(parent)
        self:clear()
        root = ui.Layer.new(parent)
        root:SetSize(0, 0, 1, 1)
        parent = root
        local title = ui.Text.new(parent)
        title:SetPos(12, 10)
        title:SetSize(-24, 24, 1, 0)
        title.font = id.Font.MUSEO_SANS_15PT_REGULAR
        title.content, title.rgba, title.clickthrough = "Spirit Spy", 0xD8C18FFF, true

        for index, option in ipairs({
            { key = "showHoverCount", label = "Show count on hover" },
            { key = "numberOnly", label = "Number only" },
            { key = "limitToBoxTier", label = "Match carried box tier" },
            { key = "warningEnabled", label = "Low-spirit warning" },
        }) do
            local button = ui.Button.new(parent)
            button:SetPos(12, 42 + (index - 1) * 40)
            button:SetSize(-24, 32, 1, 0)
            button.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
            button.text.font = id.Font.MUSEO_SANS_15PT_REGULAR
            local function refresh()
                button.label = option.label .. ": " .. (self[option.key] and "On" or "Off")
            end
            refresh()
            button:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
                self[option.key] = not self[option.key]
                if not database:SetBool(option.key, self[option.key]) then
                    log("Spirit Spy could not save " .. option.label .. ".")
                end
                refresh()
                changed()
            end)
        end

        -- Save a valid whole-number threshold when Enter is pressed or the input loses focus.
        local caption = ui.Text.new(parent)
        caption:SetPos(12, 204)
        caption:SetSize(140, 30)
        caption.font, caption.content, caption.clickthrough =
            id.Font.MUSEO_SANS_15PT_REGULAR, "Warn below:", true
        caption.rgba = 0xFFFFFFFF
        local input = ui.InputField.new(parent)
        input:SetPos(154, 202)
        input:SetSize(-166, 32, 1, 0)
        input.stylesheetID = id.StyleSheet.INPUT_DEFAULT
        input:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NUMERIC, 10)
        input.content = tostring(self.warningThreshold)
        input:Subscribe(ui.Hook.ONCONTENTCHANGED, function(_, reason, content)
            if
                reason ~= ui.InputFieldActionResult.SUBMIT
                and reason ~= ui.InputFieldActionResult.SUBMIT_ON_FOCUS_LOSS
            then
                return
            end
            local value = type(content) == "string"
                and content:match("^%d+$", 1)
                and tonumber(content, 10)
            if value and value >= 1 and value <= 2147483647 then
                self.warningThreshold = value
                database:SetInt("warningThreshold", value)
                changed()
            end
            input.content = tostring(self.warningThreshold)
        end)

        -- Let us mute the warning or test its popup and sound without spending spirits.
        local sound = ui.Button.new(parent)
        sound:SetPos(12, 244)
        sound:SetSize(-20, 32, 0.5, 0)
        sound.stylesheetID, sound.text.font =
            id.StyleSheet.BUTTON_DEFAULT, id.Font.MUSEO_SANS_15PT_REGULAR
        local function refreshSound()
            sound.label = "Sound: " .. (self.warningSound and "On" or "Off")
        end
        refreshSound()
        sound:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
            self.warningSound = not self.warningSound
            database:SetBool("warningSound", self.warningSound)
            refreshSound()
            changed()
        end)
        local test = ui.Button.new(parent)
        test:SetPos(8, 244, 0.5, 0)
        test:SetSize(-20, 32, 0.5, 0)
        test.stylesheetID, test.text.font, test.label =
            id.StyleSheet.BUTTON_DEFAULT, id.Font.MUSEO_SANS_15PT_REGULAR, "Test warning"
        test:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
            preview()
        end)
    end

    return self
end

return M
