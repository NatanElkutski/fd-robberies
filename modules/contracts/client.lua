--[[
    Contracts (client): the running mission, its GPS blip, HUD timer/briefing,
    death/timeout handling, and start/finish requests from the NUI.
    Other modules react to mission start/end through FD.Mission.OnStart / OnEnd.
]]

local sharedConfig = require('config.shared')
local config = require('config.client')

---@type RunningMission|nil
local running = nil
local missionBlip = nil
local startHandlers, endHandlers = {}, {}

FD.Mission = {}

---@return RunningMission|nil
function FD.Mission.Current()
    return running
end

---@param id string
---@return boolean
function FD.Mission.Is(id)
    return running ~= nil and running.id == id
end

---@param handler fun(id: string)
function FD.Mission.OnStart(handler)
    startHandlers[#startHandlers + 1] = handler
end

---@param handler fun(id: string)
function FD.Mission.OnEnd(handler)
    endHandlers[#endHandlers + 1] = handler
end

local function clearBlip()
    if missionBlip then
        RemoveBlip(missionBlip)
        missionBlip = nil
    end
end

---Only location robberies get a GPS route; ATM and store contracts work anywhere in the city.
---@param robbery RobberyDefinition
local function setBlip(robbery)
    clearBlip()
    if robbery.kind ~= 'location' then
        return
    end
    missionBlip = AddBlipForCoord(robbery.coords.x, robbery.coords.y, robbery.coords.z)
    SetBlipSprite(missionBlip, 1)
    SetBlipColour(missionBlip, 1)
    SetBlipRoute(missionBlip, true)
end

---@param id string
local function runHandlers(handlers, id)
    for _, handler in ipairs(handlers) do
        handler(id)
    end
end

---Stops the mission locally (HUD, blip, module state).
local function stopLocally()
    local id = running and running.id
    running = nil
    FD.Actions.Reset()
    clearBlip()
    FD.Nui.Send('mission', { show = false })
    if id then
        runHandlers(endHandlers, id)
    end
end

local STARTED_NOTIFY = { atm = 'contract.started_atm', store = 'contract.started_store' }

RegisterNetEvent(FD.Events.Client.Started, function(id, _, duration)
    local robbery = sharedConfig.robberies[id]
    if not robbery then
        return
    end

    running = { id = id, ends = GetGameTimer() + duration * 1000 }
    runHandlers(startHandlers, id)
    setBlip(robbery)

    FD.Nui.Focus(false)
    FD.Nui.Send('close')
    FD.Nui.Send('mission', {
        show = true,
        label = locale(('robbery.%s.label'):format(id)),
        briefing = FD.Utils.briefing(id),
        position = config.missionHud,
    })
    Bridge.Notify(locale(STARTED_NOTIFY[robbery.kind] or 'contract.started_location'), 'success')
end)

RegisterNetEvent(FD.Events.Client.Ended, function(id)
    if FD.Mission.Is(id) then
        stopLocally()
    end
end)

RegisterNUICallback('start', function(data, cb)
    TriggerServerEvent(FD.Events.Server.Start, data.id)
    cb('ok')
end)

RegisterNUICallback('endMission', function(_, cb)
    TriggerServerEvent(FD.Events.Server.ExitMission)
    cb('ok')
end)

-- Briefing panel toggle (hold-style mapping kept for compatibility with existing binds)
RegisterCommand('+robberybrief', function()
    if running then
        FD.Nui.Send('toggleBrief')
    end
end, false)
RegisterCommand('-robberybrief', function() end, false)
RegisterKeyMapping('+robberybrief', locale('keys.briefing'), 'keyboard', config.briefingKey)

-- HUD timer (one NUI update per second), death cancels, timeout ends locally.
CreateThread(function()
    local lastSecond = -1
    while true do
        if running then
            Wait(200)
            local left = math.max(0, math.ceil((running.ends - GetGameTimer()) / 1000))
            if left ~= lastSecond then
                lastSecond = left
                FD.Nui.Send('timer', { seconds = left })
            end

            if IsEntityDead(cache.ped) then
                TriggerServerEvent(FD.Events.Server.Cancel, running.id)
                stopLocally()
                lastSecond = -1
            elseif left <= 0 then
                stopLocally()
                lastSecond = -1
            end
        else
            lastSecond = -1
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == FD.Resource then
        clearBlip()
    end
end)
