--[[
    ATM breach (client) — explosive method: plant the thermite charge, escape countdown,
    explosion + short fire, then any crew member loots the blasted ATM.
]]

local config = require('config.client')

local PLANT_ANIM <const> = { dict = 'anim@heists@ornate_bank@thermal_charge', clip = 'thermal_charge', flag = 1 }
local CHARGE_PROP <const> =
    { model = `hei_prop_heist_thermite`, bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) }
local LOOT_ANIM <const> = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'grab', flag = 1 }
local EXPLOSION_TYPE <const> = 2
local FIRE_MS <const> = 7000
local FIND_RADIUS <const> = 2.0

FD.Atm.Explosive = {}

---Finds the ATM object at a position (the map ATM near the blast).
---@param coords vector3
---@return integer|nil
local function atmAt(coords)
    for _, model in ipairs(config.atm.models) do
        local entity =
            GetClosestObjectOfType(coords.x, coords.y, coords.z, FIND_RADIUS, joaat(model), false, false, false)
        if entity ~= 0 then
            return entity
        end
    end
end

---@param entity integer
function FD.Atm.Explosive.Start(entity)
    local ok, message = lib.callback.await(FD.Events.Callback.CheckMethod, false, 'explosive')
    if not ok then
        return Bridge.Notify(message or locale('atm.missing_gear'), 'error')
    end

    TaskTurnPedToFaceEntity(cache.ped, entity, 800)
    Wait(800)

    local done = FD.Actions.Run(locale('atm.planting'), config.atm.methodTime.explosive, PLANT_ANIM, CHARGE_PROP)
    if done == nil then
        return
    end
    if not done or not DoesEntityExist(entity) then
        return TriggerServerEvent(FD.Events.Server.ReleaseAtmMethod)
    end

    TriggerServerEvent(FD.Events.Server.ConsumeAtmItem, 'explosive')
    FD.Atm.used[entity] = true
    local pos = GetEntityCoords(entity)

    for seconds = config.atm.explosionCountdown, 1, -1 do
        Bridge.Notify(locale('atm.countdown', seconds), 'error')
        Wait(1000)
    end

    AddExplosion(pos.x, pos.y, pos.z, EXPLOSION_TYPE, 1.0, true, false, 1.0)
    local front = GetOffsetFromEntityInWorldCoords(entity, 0.0, -0.6, 0.2)
    local fire = StartScriptFire(front.x, front.y, front.z, 3, false)
    SetTimeout(FIRE_MS, function()
        RemoveScriptFire(fire)
    end)

    TriggerServerEvent(FD.Events.Server.ExplosiveReady, pos)
    Bridge.Notify(locale('atm.blasted'), 'success')
end

---@param entity integer
function FD.Atm.Explosive.Loot(entity)
    if not FD.Atm.IsActive() or not FD.Atm.blasted or entity ~= FD.Atm.blasted then
        return
    end
    if not FD.Atm.IsNear(entity, config.atm.lootDistance) then
        return Bridge.Notify(locale('atm.too_far'), 'error')
    end

    TaskTurnPedToFaceEntity(cache.ped, entity, 800)
    Wait(800)
    if FD.Actions.Run(locale('atm.collecting'), config.atm.blastLootTime, LOOT_ANIM) then
        FD.Atm.Finish('explosive_loot')
        FD.Atm.blasted = nil
    end
end

-- The server tells the whole crew which ATM was blasted, so anyone can loot it.
RegisterNetEvent(FD.Events.Client.AtmBlasted, function(coords)
    local entity = atmAt(coords)
    if entity then
        FD.Atm.blasted = entity
        FD.Atm.used[entity] = true
    end
end)

RegisterNetEvent(FD.Events.Client.LootBlastedAtm, function(data)
    FD.Atm.Explosive.Loot(type(data) == 'table' and data.entity or data)
end)
