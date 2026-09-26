--[[
    Shop (server): robbery equipment bought with the cash item or the bank account.
]]

local config = require('config.server')

---@param name string
---@return { name: string, price: integer }|nil
local function findItem(name)
    for _, item in ipairs(config.shop.items) do
        if item.name == name then
            return item
        end
    end
end

---Removes `price` from the first cash item the player has enough of.
---@param src integer
---@param price integer
---@return string|nil paidWith item name, nil when the player can't pay
---@return string|nil errorKey
local function payWithCashItem(src, price)
    local names = { config.shop.cashItem or 'cash', 'CASH', 'cash' }
    for _, name in ipairs(names) do
        if Bridge.GetItemCount(src, name) >= price then
            if Bridge.RemoveItem(src, name, price) then
                return name
            end
            return nil, 'shop.payment_failed'
        end
    end
    return nil, 'shop.not_enough_cash'
end

---@param src integer
---@param method 'cash'|'bank'
---@param price integer
---@param paidWith string|nil
local function refund(src, method, price, paidWith)
    if method == 'bank' then
        Bridge.AddMoney(src, 'bank', price, 'robbery-refund')
    else
        Bridge.AddItem(src, paidWith, price)
    end
end

RegisterNetEvent(FD.Events.Server.BuyItem, function(itemName, paymentMethod)
    local src = source
    if not Bridge.GetPlayer(src) then
        return
    end

    local item = findItem(itemName)
    if not item then
        return
    end
    if not Bridge.ItemExists(item.name) then
        return Bridge.Notify(src, locale('shop.item_not_defined', item.name), 'error')
    end

    local method = paymentMethod == 'bank' and 'bank' or 'cash'
    if (method == 'bank' and not config.shop.allowBank) or (method == 'cash' and not config.shop.allowCashItem) then
        return Bridge.Notify(src, locale('shop.payment_disabled'), 'error')
    end

    local paidWith
    if method == 'bank' then
        if Bridge.GetMoney(src, 'bank') < item.price then
            return Bridge.Notify(src, locale('shop.not_enough_bank'), 'error')
        end
        if not Bridge.RemoveMoney(src, 'bank', item.price, 'robbery-equipment') then
            return
        end
    else
        local errorKey
        paidWith, errorKey = payWithCashItem(src, item.price)
        if not paidWith then
            return Bridge.Notify(src, locale(errorKey), 'error')
        end
    end

    if not Bridge.AddItem(src, item.name, 1) then
        refund(src, method, item.price, paidWith)
        return Bridge.Notify(src, locale('shop.refunded'), 'error')
    end

    Bridge.Notify(src, locale('shop.bought', locale(('shop.items.%s.label'):format(item.name)), item.price), 'success')
end)
