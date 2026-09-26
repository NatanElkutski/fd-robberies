--[[
    Server integration wrappers (framework-agnostic). Open file.
]]

Bridge = Bridge or {}

---Shows a notification on a player's screen (rendered by Bridge.Notify on the client).
---@param src integer
---@param message string
---@param kind? 'primary'|'success'|'error'
function Bridge.Notify(src, message, kind)
    TriggerClientEvent(FD.Events.Client.Notify, src, message, kind or 'primary')
end
