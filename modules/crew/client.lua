--[[
    Crew (client): nearby-player discovery and crew actions from the NUI.
]]

local config = require('config.client')

FD.Crew = {}

---Players within the configured radius, closest first.
---@return { id: integer, name: string, distance: number }[]
function FD.Crew.Nearby()
    local origin = GetEntityCoords(cache.ped)
    local players = {}

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= cache.playerId then
            local distance = #(GetEntityCoords(GetPlayerPed(player)) - origin)
            if distance <= config.nearbyPlayersRadius then
                players[#players + 1] = {
                    id = GetPlayerServerId(player),
                    name = GetPlayerName(player),
                    distance = math.floor(distance * 10) / 10,
                }
            end
        end
    end

    table.sort(players, function(a, b)
        return a.distance < b.distance
    end)
    return players
end

RegisterNetEvent(FD.Events.Client.CrewRefresh, function()
    if not IsNuiFocused() then
        return
    end

    local data = lib.callback.await(FD.Events.Callback.GetData, false)
    if data then
        FD.Nui.Send('dataRefresh', { data = data, nearby = FD.Crew.Nearby() })
    end
end)

RegisterNUICallback('crewInvite', function(data, cb)
    TriggerServerEvent(FD.Events.Server.CrewInvite, tonumber(data.id))
    cb('ok')
end)

RegisterNUICallback('crewAccept', function(data, cb)
    TriggerServerEvent(FD.Events.Server.CrewAccept, tonumber(data.id))
    cb('ok')
end)

RegisterNUICallback('crewLeave', function(_, cb)
    TriggerServerEvent(FD.Events.Server.CrewLeave)
    cb('ok')
end)

RegisterNUICallback('refreshNearby', function(_, cb)
    FD.Nui.Send('nearby', { nearby = FD.Crew.Nearby() })
    cb('ok')
end)
