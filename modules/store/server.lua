--[[
    Store holdup (server): loot validation per store point and the rear-safe code + hints.
]]

local sharedConfig = require('config.shared')
local config = require('config.server')

local STORE <const> = 'store'

---@param code string three digits
---@return string[]
local function hintsFor(code)
    local d1, d2, d3 = tonumber(code:sub(1, 1)), tonumber(code:sub(2, 2)), tonumber(code:sub(3, 3))
    local value = tonumber(code)
    return {
        locale('store.hint_1', code:sub(1, 1), d2 + d3),
        locale('store.hint_2', code:sub(2, 2), math.max(100, value - 7), math.min(999, value + 7)),
        locale('store.hint_3', code:sub(3, 3), d1 + d2 + d3),
    }
end

---@param kind string
---@param storeId integer
---@param contract ActiveContract
---@param code any
---@return integer|nil reward
---@return string|nil errorKey
local function rollLoot(kind, storeId, contract, code)
    if kind == 'register' then
        return math.random(config.store.registerReward.min, config.store.registerReward.max)
    elseif kind == 'shelf' then
        return math.random(config.store.shelfReward.min, config.store.shelfReward.max)
    elseif kind == 'safe' then
        local expected = contract.safeCodes[storeId]
        if not expected or tostring(expected) ~= tostring(code) then
            return nil, 'store.wrong_code'
        end
        return math.random(config.store.safeReward.min, config.store.safeReward.max)
    end
end

lib.callback.register(FD.Events.Callback.GetSafeHint, function(source, storeId)
    local contract = FD.Contracts.Get(STORE)
    if not contract or not contract.members[source] then
        return false
    end

    storeId = tonumber(storeId)
    local store = storeId and sharedConfig.stores[storeId]
    if not store then
        return false
    end

    contract.safeCodes = contract.safeCodes or {}
    contract.safeCodes[storeId] = contract.safeCodes[storeId] or math.random(100, 999)

    local hints = hintsFor(tostring(contract.safeCodes[storeId]))
    return true, hints[math.random(#hints)], store.label
end)

RegisterNetEvent(FD.Events.Server.StoreAction, function(storeId, kind, index, code)
    local src = source
    local contract = FD.Contracts.Get(STORE)
    if not contract or not contract.members[src] or not Bridge.GetPlayer(src) or contract.expires < os.time() then
        return
    end

    storeId = tonumber(storeId)
    index = tonumber(index) or 1
    if not storeId or not sharedConfig.stores[storeId] then
        return
    end

    local key = ('%s:%s:%s'):format(storeId, kind, index)
    if contract.actions[key] then
        return Bridge.Notify(src, locale('store.already_looted'), 'error')
    end

    local reward, errorKey = rollLoot(kind, storeId, contract, code)
    if errorKey then
        return Bridge.Notify(src, locale(errorKey), 'error')
    end
    if not reward then
        return
    end

    contract.actions[key] = true
    FD.Rewards.GiveDirtyMoney(src, reward)
    Bridge.Notify(src, locale('store.collected', reward), 'success')
end)

-- The store contract has no single "complete" step: success = anything looted.
FD.Contracts.OnComplete(STORE, function() end)
