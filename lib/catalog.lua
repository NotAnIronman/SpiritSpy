-- Keep the supported spirit items, box tiers and target names together.
local M = {}

-- Stone spirits use named ore-box fields for their stored counts.
M.stoneSpirits = {
    { key = "copper", name = "Copper", id = 44799, varID = 11514, boxTier = 1 },
    { key = "tin", name = "Tin", id = 44800, varID = 11515, boxTier = 1 },
    { key = "iron", name = "Iron", id = 44801, varID = 11516, boxTier = 2 },
    { key = "silver", name = "Silver", id = 44802, varID = 11518, boxTier = 3 },
    { key = "gold", name = "Gold", id = 44803, varID = 11519, boxTier = 5 },
    { key = "coal", name = "Coal", id = 44804, varID = 11517, boxTier = 3 },
    { key = "mithril", name = "Mithril", id = 44805, varID = 11520, boxTier = 4 },
    { key = "luminite", name = "Luminite", id = 44806, varID = 11523, boxTier = 5 },
    { key = "adamantite", name = "Adamantite", id = 44807, varID = 11521, boxTier = 5 },
    { key = "runite", name = "Runite", id = 44808, varID = 11522, boxTier = 6 },
    { key = "orichalcite", name = "Orichalcite", id = 44809, varID = 11524, boxTier = 7 },
    { key = "drakolith", name = "Drakolith", id = 44810, varID = 11525, boxTier = 7 },
    { key = "necrite", name = "Necrite", id = 44811, varID = 11526, boxTier = 8 },
    { key = "phasmatite", name = "Phasmatite", id = 44812, varID = 11527, boxTier = 8 },
    { key = "banite", name = "Banite", id = 44813, varID = 11528, boxTier = 9 },
    { key = "light_animica", name = "Light animica", id = 44814, varID = 11529, boxTier = 10 },
    { key = "dark_animica", name = "Dark animica", id = 44815, varID = 11530, boxTier = 10 },
}

-- Wood spirits use the shared wood-box inventory instead.
M.woodSpirits = {
    { key = "normal", name = "Normal", id = 54915, boxTier = 1 },
    { key = "oak", name = "Oak", id = 54916, boxTier = 2 },
    { key = "willow", name = "Willow", id = 54917, boxTier = 3 },
    { key = "teak", name = "Teak", id = 54918, boxTier = 4 },
    { key = "maple", name = "Maple", id = 54919, boxTier = 5 },
    { key = "acadia", name = "Acadia", id = 54920, boxTier = 6 },
    { key = "mahogany", name = "Mahogany", id = 54921, boxTier = 7 },
    { key = "yew", name = "Yew", id = 54922, boxTier = 8 },
    { key = "magic", name = "Magic", id = 54923, boxTier = 9 },
    { key = "elder", name = "Elder", id = 54924, boxTier = 10 },
    { key = "eternal_magic", name = "Eternal magic", id = 58255, boxTier = 11 },
}

-- Build the item-ID lookups for carried boxes and their highest supported tiers.
M.boxes = { stone = {}, wood = {} }
for tier = 1, 10 do
    M.boxes.stone[44777 + tier * 2] = tier
    M.boxes.wood[54893 + tier * 2] = tier
end
M.boxes.wood[58253] = 11
M.spirits = {}

local byItem, rocks, trees = {}, {}, {}

-- Match the rock names the client may use to their stone spirit.
for _, spirit in ipairs(M.stoneSpirits) do
    spirit.kind, spirit.label = "stone", spirit.name .. " Stone"
    M.spirits[#M.spirits + 1] = spirit
    byItem[spirit.id] = spirit
    spirit.varName = "MINING_OREBOX_" .. spirit.key:upper() .. "_STONE_SPIRIT_VAR"
    local name = spirit.name:lower()
    for _, suffix in ipairs({ "", " rock", " rocks", " ore rock", " ore rocks" }) do
        rocks[name .. suffix] = spirit
    end
end
rocks["concentrated coal rocks"] = byItem[44804]
rocks["concentrated gold rocks"] = byItem[44803]
rocks["adamant rock"] = byItem[44807]
rocks["adamant rocks"] = byItem[44807]
rocks["rune rock"] = byItem[44808]
rocks["rune rocks"] = byItem[44808]
rocks["bane rock"] = byItem[44813]
rocks["bane rocks"] = byItem[44813]

-- Match tree names to wood spirits, including ordinary trees with different names.
for _, spirit in ipairs(M.woodSpirits) do
    spirit.kind = "wood"
    spirit.label = spirit.key == "normal" and "Wood" or spirit.name .. " Wood"
    byItem[spirit.id] = spirit
    M.spirits[#M.spirits + 1] = spirit
    local name = spirit.name:lower()
    for _, ending in ipairs({ "", " tree", " trees" }) do
        trees[name .. ending] = spirit
    end
end
for _, name in ipairs({
    "tree",
    "trees",
    "dead tree",
    "dead snowy tree",
    "dead tree covered in snow",
    "evergreen",
    "jungle tree",
    "jungle bush",
    "swamp tree",
    "dying tree",
}) do
    trees[name] = byItem[54915]
end

-- Strip game text tags and tidy spaces before comparing names.
function M.normalise(value)
    if type(value) == "userdata" then
        value = tostring(value)
    end
    if type(value) ~= "string" then
        return ""
    end
    return value
        :gsub("<[^>]*>", "", math.maxinteger)
        :lower()
        :gsub("%s+", " ", math.maxinteger)
        :match("^%s*(.-)%s*$", 1)
end

-- These lookups keep the rest of the plugin from needing to know how the lists are stored.
function M.rock(name)
    return rocks[M.normalise(name)]
end
function M.tree(name)
    return trees[M.normalise(name)]
end
function M.target(name)
    return M.rock(name) or M.tree(name)
end
function M.item(id)
    return byItem[id]
end

-- Only accept valid whole counts. An unreadable field stays unknown.
function M.isCount(value)
    return type(value) == "number" and value >= 0 and value <= 2147483647 and value % 1 == 0
end

-- Build either a full spirit label or just the count, with commas for large numbers.
function M.label(spirit, count, numberOnly)
    if count == nil then
        return numberOnly and "?" or spirit.label .. " Spirits: unavailable"
    end
    local number = string.format("%.0f", count)
    number = number
        :reverse()
        :gsub("(%d%d%d)", "%1,", math.maxinteger)
        :reverse()
        :gsub("^,", "", math.maxinteger)
    if numberOnly then
        return number
    end
    return number .. " " .. spirit.label .. (count == 1 and " Spirit" or " Spirits")
end

return M
