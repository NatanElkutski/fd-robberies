--[[
    Core (client): NUI messaging/focus, busy-guarded progress actions and
    server notifications.
]]

local DEFAULT_ANIM <const> = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 }

local busy = false

FD.Nui = {}
FD.Actions = {}

---@param action string
---@param payload? table
function FD.Nui.Send(action, payload)
    local message = payload or {}
    message.action = action
    SendNUIMessage(message)
end

---@param enabled boolean
function FD.Nui.Focus(enabled)
    SetNuiFocus(enabled, enabled)
    if enabled then
        SetNuiFocusKeepInput(false)
    end
end

---Runs a progress bar unless another action is running.
---@param label? string
---@param duration? integer ms
---@param anim? { dict: string, clip: string, flag?: integer }
---@return boolean|nil completed; nil when another action was already running
function FD.Actions.Run(label, duration, anim)
    if busy then
        return nil
    end

    busy = true
    local completed = Bridge.Progress({
        label = tostring(label or locale('actions.default')),
        duration = tonumber(duration) or 5000,
        anim = anim or DEFAULT_ANIM,
    })
    ClearPedTasks(cache.ped)
    busy = false
    return completed
end

function FD.Actions.Reset()
    busy = false
end

RegisterNetEvent(FD.Events.Client.Notify, function(message, kind)
    Bridge.Notify(message, kind)
end)

RegisterNUICallback('close', function(_, cb)
    FD.Nui.Focus(false)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == FD.Resource then
        SetNuiFocus(false, false)
    end
end)
