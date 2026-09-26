--[[
    Location robberies (client): a target zone at each location robbery's coords.
]]

local sharedConfig = require('config.shared')
local config = require('config.client')

---@param id string
local function performRobbery(id)
    if not FD.Mission.Is(id) then
        return
    end
    if FD.Actions.Run(locale('location.performing'), config.location.actionTime) then
        TriggerServerEvent(FD.Events.Server.Complete, id, 'location')
    end
end

CreateThread(function()
    while not Bridge.Target.IsReady() do
        Wait(500)
    end

    for id, robbery in pairs(sharedConfig.robberies) do
        if robbery.kind == 'location' then
            local zone = ('je_robbery_%s'):format(id)
            Bridge.Target.AddCircleZone(zone, robbery.coords, config.location.zoneRadius, {
                {
                    icon = 'fas fa-mask',
                    label = locale('target.location_action', locale(('robbery.%s.label'):format(id))),
                    canInteract = function()
                        return FD.Mission.Is(id)
                    end,
                    onSelect = function()
                        performRobbery(id)
                    end,
                },
            }, config.location.targetDistance)
        end
    end
end)
