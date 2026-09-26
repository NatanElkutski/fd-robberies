--[[
    ATM breach (server): method locking and item checks, drill/explosive payout,
    and the rope flow. One ATM per contract.

    Rope flow: when the ATM is ripped out, the puller's client hides the map ATM and spawns a
    networked ATM prop in its place (map ATMs aren't networked, so they can't be synced or
    looted by the crew). The server tracks that prop, hides the map ATM for every player
    (including late joiners), and on contract end deletes the prop and restores the map ATM.
]]

local config = require('config.server')

local ATM <const> = 'atm'
local LOOT_RANGE <const> = 6.0 -- max distance between the looter and the ripped ATM

---@type { coords: vector3, model: integer }[] map ATMs currently hidden for everyone
local hidden = {}

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

---@param contract ActiveContract
---@param event string
local function toCrew(contract, event, ...)
    for member in pairs(contract.members) do
        TriggerClientEvent(event, member, ...)
    end
end

---@param value any
---@return boolean
local function isCoords(value)
    local kind = type(value)
    return (kind == 'vector3' or kind == 'table')
        and tonumber(value.x) ~= nil
        and tonumber(value.y) ~= nil
        and tonumber(value.z) ~= nil
end

---@param netId? integer
local function deleteProp(netId)
    if not netId then
        return
    end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

---@param src integer
---@param netId integer
---@return boolean inRange (true when the entity isn't known server-side yet)
local function isNearEntity(src, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return true
    end
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity)) <= LOOT_RANGE
end

-- Callbacks ------------------------------------------------------------------

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

-- Map ATMs hidden right now (for players who join or restart mid-robbery).
lib.callback.register(FD.Events.Callback.GetHiddenAtms, function()
    return hidden
end)

-- Method lock / items ---------------------------------------------------------

RegisterNetEvent(FD.Events.Server.ReleaseAtmMethod, function()
    local src = source
    local contract = FD.Contracts.Get(ATM)
    if contract and contract.atmInProgress == src and not contract.atmCompleted and not contract.ropeATM then
        contract.atmInProgress = nil
        contract.atmMethod = nil
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

-- Explosive --------------------------------------------------------------------

RegisterNetEvent(FD.Events.Server.ExplosiveReady, function(coords)
    local src = source
    local contract = FD.Contracts.Get(ATM)
    if not contract or contract.atmInProgress ~= src or contract.atmCompleted then
        return
    end

    contract.explosiveReady = true
    if isCoords(coords) then
        -- every crew member can loot the blasted ATM, not only the one who planted the charge
        toCrew(contract, FD.Events.Client.AtmBlasted, vec3(coords.x, coords.y, coords.z))
    end
end)

-- Rope -------------------------------------------------------------------------

---Called by the puller as soon as the rope is tied: the wall ATM was swapped for a networked prop.
RegisterNetEvent(FD.Events.Server.RegisterRopeAtm, function(netId, coords, model)
    local src = source
    local contract = contractFor(src)
    if not contract or contract.atmCompleted or contract.atmInProgress ~= src then
        return
    end

    netId, model = tonumber(netId), tonumber(model)
    if not netId or netId <= 0 or not model or not isCoords(coords) then
        return
    end

    local position = vec3(coords.x, coords.y, coords.z)
    contract.ropeATM = netId
    contract.ropeOwner = src
    contract.ropeLooted = {}
    contract.ropeLootable = false
    contract.hiddenAtm = { coords = position, model = model }

    hidden[#hidden + 1] = contract.hiddenAtm
    TriggerClientEvent(FD.Events.Client.HideAtm, -1, position, model)
    toCrew(contract, FD.Events.Client.CrewRopeAtm, netId)
end)

---Mirrors the tow rope for the rest of the crew (vehicleNetId = nil clears it).
RegisterNetEvent(FD.Events.Server.RopeTowSync, function(vehicleNetId, towing)
    local src = source
    local contract = contractFor(src)
    if not contract or contract.ropeOwner ~= src or not contract.ropeATM then
        return
    end

    vehicleNetId = tonumber(vehicleNetId)
    towing = towing == true
    for member in pairs(contract.members) do
        if member ~= src then
            TriggerClientEvent(FD.Events.Client.CrewRopeTow, member, vehicleNetId, contract.ropeATM, towing)
        end
    end
end)

---The steel body attached behind a thin ATM panel when it is ripped out (deleted together with the ATM).
RegisterNetEvent(FD.Events.Server.RegisterAtmBody, function(netId)
    local src = source
    local contract = contractFor(src)
    netId = tonumber(netId)
    if not contract or contract.ropeOwner ~= src or not netId or netId <= 0 then
        return
    end
    contract.atmBody = netId
end)

RegisterNetEvent(FD.Events.Server.RopeLootable, function(netId)
    local src = source
    local contract = FD.Contracts.Get(ATM)
    netId = tonumber(netId)
    if not contract or contract.ropeOwner ~= src or contract.ropeATM ~= netId then
        return
    end

    contract.ropeLootable = true
    toCrew(contract, FD.Events.Client.CrewRopeLootable, netId)
end)

RegisterNetEvent(FD.Events.Server.RopeLoot, function(netId)
    local src = source
    local contract = contractFor(src)
    netId = tonumber(netId)
    if not netId or not contract or not Bridge.GetPlayer(src) or contract.expires < os.time() then
        return
    end
    if contract.ropeATM ~= netId or not contract.ropeLootable then
        return
    end
    if not isNearEntity(src, netId) then
        return Bridge.Notify(src, locale('atm.too_far'), 'error')
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
    Bridge.Notify(src, locale('atm.share_taken', amount), 'success')

    local everyone = true
    for member in pairs(contract.members) do
        if not contract.ropeLooted[member] then
            everyone = false
        end
    end
    if everyone then
        -- the money is out: the rope and the ATM prop go away (the wall stays empty until the contract ends)
        toCrew(contract, FD.Events.Client.RopeAllLooted, netId)
        SetTimeout(1500, function()
            deleteProp(netId)
            deleteProp(contract.atmBody)
        end)
    end
end)

-- Drill / explosive payout (FD.Events.Server.Complete) -----------------------------

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

-- Contract end: delete the ripped ATM prop and bring the map ATM back ----------------

---@param record { coords: vector3, model: integer }
local function restore(record)
    for index, entry in ipairs(hidden) do
        if entry == record then
            table.remove(hidden, index)
            break
        end
    end
    TriggerClientEvent(FD.Events.Client.RestoreAtm, -1, record.coords, record.model)
end

FD.Contracts.OnClose(function(id, contract)
    if id ~= ATM then
        return
    end

    deleteProp(contract.ropeATM)
    deleteProp(contract.atmBody)
    if contract.hiddenAtm then
        restore(contract.hiddenAtm)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= FD.Resource then
        return
    end
    local contract = FD.Contracts.Get(ATM)
    deleteProp(contract and contract.ropeATM)
    deleteProp(contract and contract.atmBody)
end)
