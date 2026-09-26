--[[
    Chat (client): relays lobby chat between the server and the NUI.
]]

RegisterNetEvent(FD.Events.Client.LobbyMessage, function(message)
    FD.Nui.Send('lobbyMessage', { message = message })
end)

RegisterNUICallback('lobbyMessage', function(data, cb)
    local text = tostring(data?.text or '')
    if text ~= '' then
        TriggerServerEvent(FD.Events.Server.LobbyMessage, text)
    end
    cb({ ok = true })
end)

-- The chat input needs keyboard focus while typing.
RegisterNUICallback('chatFocus', function(_, cb)
    FD.Nui.Focus(true)
    cb({ ok = true })
end)
