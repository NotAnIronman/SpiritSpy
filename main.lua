-- Connect the spirit counts, native hover text, settings and low-spirit warning.
local Catalog = require("lib/catalog")
local Reader = require("lib/reader")
local hover = require("lib/native_hover").new()
local alerts = require("lib/alerts").new()
local warning = require("lib/warning").new()
local settings
settings = require("lib/settings").new(PersistentDB, function()
    hover:clear()
    warning:clear()
end, function()
    warning:show({ "Spirit Spy warning test" }, settings)
end)
local focused = true
local reference = "spirit-spy"

-- Give the reader access to backpack items, wood-box storage and the named game fields.
local reader = Reader.new({
    backpackID = config.Inv.INV.id,
    woodboxID = config.Inv.WOODCUTTING_WOODBOX.id,
    available = function()
        return Player.IsAvailable()
    end,
    slots = function(id)
        local inventory = Inventory.Find(id)
        if not inventory or not inventory.isValid then
            return nil
        end
        return inventory:GetSlots()
    end,
    variableByName = function(name)
        return var.VarPlayer[name]
    end,
    variableByID = function(id)
        return var.VarPlayer.FromID(id)
    end,
})

-- Remember our own menu edits so repeated updates do not add the count twice.
local originals = setmetatable({}, { __mode = "k" })
local subscriptions = {}
local function subscribe(name, callback)
    Event[name].Subscribe(reference, callback)
    subscriptions[#subscriptions + 1] = name
end

-- Match rocks and trees, then add the right stored count to their existing menu text.
subscribe("MiniMenuReady", function(event)
    local carried = {}
    local counts = {}
    local hoverName, hoverSuffix
    local entries = event.miniMenu.entries
    for index, entry in ipairs(entries) do
        local old = originals[entry]
        if old and entry.overrideText == old.rendered then
            entry.overrideText = old.original
        end
        originals[entry] = nil
        local loc = entry.locData
        if entry.actionEntryType == MiniMenuEntryType.LOC and loc then
            local spirit = Catalog.target(entry.subjectText) or Catalog.target(loc.config.name)
            if spirit then
                if carried[spirit.kind] == nil then
                    carried[spirit.kind] = reader:hasBox(spirit.kind)
                end
                if
                    carried[spirit.kind] and (not settings.limitToBoxTier or reader:canHold(spirit))
                then
                    local cached = counts[spirit.key]
                    if not cached then
                        cached = { value = reader:count(spirit) }
                        counts[spirit.key] = cached
                    end
                    local original = entry.overrideText or ""
                    local base = original
                    if not base or base == "" then
                        base = entry.fullText
                    end
                    local countLabel = Catalog.label(spirit, cached.value, settings.numberOnly)
                    local rendered = base .. " <col=80d8ff>(" .. countLabel .. ")</col>"
                    entry.overrideText = rendered
                    originals[entry] = { original = original, rendered = rendered }
                    if index == #entries then
                        local name = Catalog.target(entry.subjectText) and entry.subjectText
                            or loc.config.name
                        hoverName = name
                        hoverSuffix = " <col=80d8ff>(" .. countLabel .. ")</col>"
                    end
                end
            end
        end
    end
    if hoverName and settings.showHoverCount and focused and not MiniMenu.IsOpen() then
        hover:setTarget(hoverName, hoverSuffix)
    else
        hover:clear()
    end
end)

-- Tell the reader when box or backpack contents may have changed.
subscribe("InventoryAdded", function(event)
    reader:inventoryChanged(event.inv)
end)
subscribe("InventoryUpdated", function(event)
    reader:inventoryChanged(event.inv)
end)
subscribe("InventoryRemoved", function(event)
    reader:inventoryChanged(event.inv)
end)
local paused = false

-- Clear old storage readings and warnings when the game changes state.
subscribe("GameStateChanged", function(event)
    paused = event.newState ~= GameState.GAME
    reader:reset()
    hover:clear()
    alerts:reset()
    warning:clear()
end)

-- Check for falling spirit counts at a slower pace, even when we are not hovering a target.
subscribe("Logic", function(event)
    if paused or not Player.IsAvailable() then
        alerts:reset()
        warning:clear()
        return
    end
    if event.logicTick % 25 == 0 then
        warning:show(alerts:check(reader, settings), settings)
    end
end)

-- Update the native hover text and any active warning popup.
subscribe("Draw", function(event)
    hover:draw()
    warning:draw(event.timeDeltaSecs, focused)
end)

-- Restore native hover text when menus open or the game loses focus.
subscribe("MiniMenuOpened", function()
    hover:clear()
end)
subscribe("WindowFocusChanged", function(event)
    focused = event.hasFocus
    if not focused then
        hover:clear()
    end
end)
subscribe("SettingsLayerReady", function(event)
    settings:build(event.component)
end)

-- Remove our callbacks and restore or clear every display we changed.
function PluginShutdown()
    for _, name in ipairs(subscriptions) do
        Event[name].Unsubscribe(reference)
    end
    hover:clear()
    alerts:reset()
    warning:clear()
    settings:clear()
end
