--[[
    Shop (client): purchase requests from the NUI. Prices are enforced by the server.
]]

RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent(FD.Events.Server.BuyItem, data.item, data.paymentMethod)
    cb('ok')
end)
