--[[
    ATM breach (client) — explosive method: plant the charge, escape countdown,
    explosion, then loot the blasted ATM.
]]

local config = require('config.client')

local EXPLOSION_TYPE <const> = 2

FD.Atm.Explosive = {}

---@param entity integer
function FD.Atm.Explosive.Start(entity)
    local ok, message = lib.callback.await(FD.Events.Callback.CheckMethod, false, 'explosive')
    if not ok then
        return Bridge.Notify(message or locale('atm.missing_gear'), 'error')
    end

    local done = FD.Actions.Run(locale('atm.planting'), config.atm.methodTime.explosive)
    if done == nil then
        return
    end
    if not done or not DoesEntityExist(entity) then
        return TriggerServerEvent(FD.Events.Server.ReleaseAtmMethod)
    end

    TriggerServerEvent(FD.Events.Server.ConsumeAtmItem, 'explosive')
    FD.Atm.used[entity] = true

    for seconds = config.atm.explosionCountdown, 1, -1 do
        Bridge.Notify(locale('atm.countdown', seconds), 'error')
        Wait(1000)
    end

    local pos = GetEntityCoords(entity)
    AddExplosion(pos.x, pos.y, pos.z, EXPLOSION_TYPE, 1.0, true, false, 1.0)
    FD.Atm.blasted = entity
    TriggerServerEvent(FD.Events.Server.ExplosiveReady)
    Bridge.Notify(locale('atm.blasted'), 'success')
end

---@param entity integer
function FD.Atm.Explosive.Loot(entity)
    if not FD.Atm.IsActive() or not FD.Atm.blasted or entity ~= FD.Atm.blasted then
        return
    end
    if not FD.Atm.IsNear(entity, config.atm.lootDistance) then
        return
    end

    if FD.Actions.Run(locale('atm.collecting'), config.atm.blastLootTime) then
        FD.Atm.Finish('explosive_loot')
        FD.Atm.blasted = nil
    end
end

RegisterNetEvent(FD.Events.Client.LootBlastedAtm, function(data)
    FD.Atm.Explosive.Loot(type(data) == 'table' and data.entity or data)
end)
