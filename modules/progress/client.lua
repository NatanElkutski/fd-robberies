--[[
    Progress (client): criminal profile save from the NUI.
]]

RegisterNUICallback('saveCriminalProfile', function(data, cb)
    TriggerServerEvent(FD.Events.Server.SaveProfile, data.name, data.avatar)
    cb('ok')
end)
