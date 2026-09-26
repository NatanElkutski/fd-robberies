--[[
    ATM breach (client) — drill method: one long progress, then the server pays out.
]]

local config = require('config.client')

FD.Atm.Drill = {}

---@param entity integer
function FD.Atm.Drill.Start(entity)
    local ok, message = lib.callback.await(FD.Events.Callback.CheckMethod, false, 'drill')
    if not ok then
        return Bridge.Notify(message or locale('atm.missing_gear'), 'error')
    end

    local done = FD.Actions.Run(locale('atm.drilling'), config.atm.methodTime.drill)
    if done == nil then
        return
    end

    if done then
        FD.Atm.used[entity] = true
        FD.Atm.Finish('drill')
    else
        TriggerServerEvent(FD.Events.Server.ReleaseAtmMethod)
    end
end
