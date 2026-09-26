--[[
    Rewards (server): pays robbery loot as dirty money with fallbacks,
    so a successful robbery never pays zero.
]]

local config = require('config.server')

FD.Rewards = {}

---Tries the dirty-money item (as configured, lower, upper case), then the fallback cash item,
---then 'cash', then the framework cash account.
---@param src integer
---@param amount integer
---@return boolean paid
---@return string|nil paidAs item name or 'cash-account'
function FD.Rewards.GiveDirtyMoney(src, amount)
    if not Bridge.GetPlayer(src) or not amount or amount <= 0 then
        return false
    end

    local wanted = config.dirtyMoneyItem or 'dirtymoney'
    local candidates = {
        wanted,
        string.lower(wanted),
        string.upper(wanted),
        config.fallbackCashItem or 'CASH',
        'cash',
    }

    local tried = {}
    for _, name in ipairs(candidates) do
        if not tried[name] then
            tried[name] = true
            local itemName = Bridge.ResolveItemName(name)
            if itemName and Bridge.AddItem(src, itemName, amount) then
                return true, itemName
            end
        end
    end

    if Bridge.AddMoney(src, 'cash', amount, 'robbery-reward-fallback') then
        return true, 'cash-account'
    end

    return false
end
