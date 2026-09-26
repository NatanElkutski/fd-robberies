--[[
    ATM breach (server): method locking and item checks, drill/explosive payout,
    and the rope flow (register ripped ATM, lootable state, per-member shares).
    One ATM per contract.
]]

local config = require('config.server')

local ATM <const> = 'atm'

---@param src integer
---@return ActiveContract|nil
local function contractFor(src)
    local contract = FD.Contracts.Get(ATM)
    if contract and contract.members[src] then
        return contract
    end
end

---@param method string
---@return string|false|nil item required for the method
local function requiredItem(method)
    return config.atmItems[method]
end

lib.callback.register(FD.Events.Callback.CheckMethod, function(source, method)
    local contract = contractFor(source)
    if not Bridge.GetPlayer(source) or not contract then
        return false, locale('atm.no_active')
    end
    if contract.atmCompleted then
        return false, locale('atm.already_robbed_return')
    end
    if contract.atmInProgress and contract.atmInProgress ~= source then
        return false, locale('atm.member_in_progress')
    end

    local item = requiredItem(method)
    if item and Bridge.GetItemCount(source, item) < 1 then
        return false, locale('atm.missing_item', item)
    end

    contract.atmInProgress = source
    contract.atmMethod = method
    return true
end)

RegisterNetEvent(FD.Events.Server.ReleaseAtmMethod, function()
    local src = source
    local contract = FD.Contracts.Get(ATM)
    if contract and contract.atmInProgress == src and not contract.atmCompleted then
        contract.atmInProgress = nil
        contract.atmMethod = nil
    end
end)

RegisterNetEvent(FD.Events.Server.ExplosiveReady, function()
    local src = source
    local contract = FD.Contracts.Get(ATM)
    if contract and contract.atmInProgress == src and not contract.atmCompleted then
        contract.explosiveReady = true
    end
end)

RegisterNetEvent(FD.Events.Server.ConsumeAtmItem, function(method)
    local src = source
    if not Bridge.GetPlayer(src) or not FD.Contracts.IsMember(ATM, src) then
        return
    end

    local item = requiredItem(method)
    if item then
        Bridge.RemoveItem(src, item, 1)
    end
end)

RegisterNetEvent(FD.Events.Server.RegisterRopeAtm, function(netId)
    local src = source
    local contract = contractFor(src)
    if not contract or contract.atmCompleted then
        return
    end

    netId = tonumber(netId)
    if not netId or netId <= 0 then
        return
    end

    contract.ropeATM = netId
    contract.ropeLooted = {}
    contract.ropeLootable = false
    for member in pairs(contract.members) do
        TriggerClientEvent(FD.Events.Client.CrewRopeAtm, member, netId)
    end
end)

RegisterNetEvent(FD.Events.Server.RopeLootable, function(netId)
    local src = source
    local contract = FD.Contracts.Get(ATM)
    netId = tonumber(netId)
    if not contract or contract.owner ~= src or contract.ropeATM ~= netId then
        return
    end

    contract.ropeLootable = true
    for member in pairs(contract.members) do
        TriggerClientEvent(FD.Events.Client.CrewRopeLootable, member, netId)
    end
end)

RegisterNetEvent(FD.Events.Server.RopeLoot, function(netId)
    local src = source
    local contract = contractFor(src)
    netId = tonumber(netId)
    if not contract or not Bridge.GetPlayer(src) or contract.expires < os.time() then
        return
    end
    if contract.ropeATM ~= netId or not contract.ropeLootable then
        return
    end

    contract.ropeLooted = contract.ropeLooted or {}
    if contract.ropeLooted[src] then
        return Bridge.Notify(src, locale('atm.share_already_taken'), 'error')
    end

    local shareKey = 'rope:' .. src
    contract.ropeLooted[src] = true
    contract.actions[shareKey] = true

    local amount = FD.Contracts.RollReward(ATM)
    if not FD.Rewards.GiveDirtyMoney(src, amount) then
        contract.ropeLooted[src] = nil
        contract.actions[shareKey] = nil
        return Bridge.Notify(src, locale('atm.reward_failed_inventory'), 'error')
    end

    contract.atmCompleted = true
    contract.atmInProgress = nil
    contract.ropeDetached = true
    Bridge.Notify(src, locale('atm.share_taken', amount), 'success')

    for member in pairs(contract.members) do
        TriggerClientEvent(FD.Events.Client.DetachRopeAfterLoot, member, netId)
        TriggerClientEvent(FD.Events.Client.RopeAllLooted, member, netId)
    end
end)

-- Drill and explosive finish through FD.Events.Server.Complete.
FD.Contracts.OnComplete(ATM, function(src, id, method, contract)
    if contract.atmCompleted then
        return Bridge.Notify(src, locale('atm.already_robbed_xp'), 'error')
    end
    if method ~= 'drill' and method ~= 'explosive_loot' then
        return
    end
    if method == 'explosive_loot' and not contract.explosiveReady then
        return
    end

    if method == 'drill' then
        local item = requiredItem('drill')
        if item then
            Bridge.RemoveItem(src, item, 1)
        end
    end

    local amount = FD.Contracts.RollReward(id)
    if not FD.Rewards.GiveDirtyMoney(src, amount) then
        return Bridge.Notify(src, locale('atm.reward_failed'), 'error')
    end

    contract.atmCompleted = true
    contract.atmInProgress = nil
    contract.actions['atm:completed'] = true
    contract.objectiveDone = true
    Bridge.Notify(src, locale('atm.robbed', amount), 'success')
end)
