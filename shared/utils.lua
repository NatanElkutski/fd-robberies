--[[
    Pure helpers with no game, framework or module dependencies.
]]

FD.Utils = {}

---@param xp integer
---@param xpPerLevel integer
---@param maxLevel integer
---@return integer
function FD.Utils.levelFromXp(xp, xpPerLevel, maxLevel)
    return math.min(maxLevel, math.floor(xp / xpPerLevel) + 1)
end

---@param value any
---@return string
function FD.Utils.trim(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

---Counts entries of a map-like table.
---@param map table
---@return integer
function FD.Utils.count(map)
    local total = 0
    for _ in pairs(map) do
        total += 1
    end
    return total
end

---Returns the list of translated briefing steps for a robbery (locales: robbery.<id>.briefing.<n>).
---@param robberyId string
---@return string[]
function FD.Utils.briefing(robberyId)
    local steps = {}
    local index = 1
    while true do
        local key = ('robbery.%s.briefing.%d'):format(robberyId, index)
        local text = locale(key)
        if text == key then
            break
        end
        steps[index] = text
        index += 1
    end
    return steps
end
