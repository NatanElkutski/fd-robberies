--[[
    Chat (server): the underground lobby chat shown in the hub.
]]

local config = require('config.server')

---@type { id: integer, name: string, text: string, time: integer }[]
local history = {}

FD.Chat = {}

---@return table[]
function FD.Chat.History()
    return history
end

RegisterNetEvent(FD.Events.Server.LobbyMessage, function(message)
    local src = source
    message = tostring(message or ''):sub(1, config.chat.maxLength)
    if message:gsub('%s', '') == '' then
        return
    end

    local entry = { id = src, name = FD.Progress.DisplayName(src), text = message, time = os.time() }
    history[#history + 1] = entry
    while #history > config.chat.history do
        table.remove(history, 1)
    end

    TriggerClientEvent(FD.Events.Client.LobbyMessage, -1, entry)
end)
