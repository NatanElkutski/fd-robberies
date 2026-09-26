--[[
    Hub (server): the data payload behind the robbery menu.
]]

local config = require('config.server')

---@return table<string, integer>
local function xpRewards()
    local rewards = {}
    for id, robbery in pairs(config.robberies) do
        rewards[id] = robbery.xp
    end
    return rewards
end

---@return { name: string, price: integer, icon: string }[]
local function shopItems()
    local items = {}
    for index, item in ipairs(config.shop.items) do
        items[index] = { name = item.name, price = item.price, icon = item.icon }
    end
    return items
end

lib.callback.register(FD.Events.Callback.GetData, function(source)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then
        return nil
    end

    return {
        progress = FD.Progress.Get(identifier),
        robberies = FD.Contracts.States(),
        xpPerLevel = config.xpPerLevel,
        xpRewards = xpRewards(),
        crew = FD.Crew.Payload(source),
        chat = FD.Chat.History(),
        shop = {
            items = shopItems(),
            allowCash = config.shop.allowCashItem,
            allowBank = config.shop.allowBank,
        },
    }
end)
