--[[
    ATM breach (client) — drill method: drill into the ATM (drill prop + sparks), then the server pays out.
]]

local config = require('config.client')

local DRILL_ANIM <const> = { dict = 'anim@heists@fleeca_bank@drilling', clip = 'drill_straight_idle', flag = 1 }
local DRILL_PROP <const> = {
    model = `hei_prop_heist_drill`,
    bone = 57005,
    pos = vec3(0.14, 0.0, -0.01),
    rot = vec3(90.0, -90.0, 180.0),
}
local SPARK_INTERVAL_MS <const> = 350

FD.Atm.Drill = {}

---Sparks at the ATM face while the drill runs.
---@param entity integer
---@return fun() stop
local function sparksOn(entity)
    local running = true
    CreateThread(function()
        if not FD.Atm.LoadPtfx('core') then
            return
        end
        while running and DoesEntityExist(entity) do
            local face = GetOffsetFromEntityInWorldCoords(entity, 0.0, -0.35, 1.0)
            FD.Atm.Burst('ent_dst_elec_fire_sp', face, 0.3)
            Wait(SPARK_INTERVAL_MS)
        end
    end)
    return function()
        running = false
    end
end

---@param entity integer
function FD.Atm.Drill.Start(entity)
    local ok, message = lib.callback.await(FD.Events.Callback.CheckMethod, false, 'drill')
    if not ok then
        return Bridge.Notify(message or locale('atm.missing_gear'), 'error')
    end

    TaskTurnPedToFaceEntity(cache.ped, entity, 800)
    Wait(800)

    local stopSparks = sparksOn(entity)
    local done = FD.Actions.Run(locale('atm.drilling'), config.atm.methodTime.drill, DRILL_ANIM, DRILL_PROP)
    stopSparks()

    if done == nil then
        return
    end

    if done and DoesEntityExist(entity) then
        FD.Atm.used[entity] = true
        FD.Atm.Finish('drill')
    else
        TriggerServerEvent(FD.Events.Server.ReleaseAtmMethod)
    end
end
