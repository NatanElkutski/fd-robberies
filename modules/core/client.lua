--[[
    Core (client): NUI messaging/focus, busy-guarded progress actions and
    server notifications.
]]

local DEFAULT_ANIM <const> = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 }

local busy = false
-- set when the NUI page has loaded and mounted (it posts 'ready'); focus is never taken before that,
-- so a missing/broken UI build can't leave the player with a frozen mouse
local uiReady = false

FD.Nui = {}
FD.Actions = {}

---@param action string
---@param payload? table
function FD.Nui.Send(action, payload)
    local message = payload or {}
    message.action = action
    SendNUIMessage(message)
end

---@return boolean
function FD.Nui.IsReady()
    return uiReady
end

---Gives/releases mouse+keyboard focus. Refuses to take focus while the UI isn't loaded.
---@param enabled boolean
---@return boolean focused
function FD.Nui.Focus(enabled)
    if enabled and not uiReady then
        print(
            ('^1[%s] The UI is not loaded. Build it with: cd web && npm install && npm run build, then refresh + ensure the resource.^7'):format(
                FD.Resource
            )
        )
        Bridge.Notify(locale('notify.ui_not_ready'), 'error')
        return false
    end

    SetNuiFocus(enabled, enabled)
    if enabled then
        SetNuiFocusKeepInput(false)
    end
    return enabled
end

RegisterNUICallback('ready', function(_, cb)
    uiReady = true
    cb('ok')
end)

-- The UI crashed: release focus so the player isn't stuck.
RegisterNUICallback('uiError', function(data, cb)
    print(('^1[%s] UI error: %s^7'):format(FD.Resource, tostring(data?.message)))
    SetNuiFocus(false, false)
    cb('ok')
end)

---Runs a progress bar unless another action is running.
---@param label? string
---@param duration? integer ms
---@param anim? { dict: string, clip: string, flag?: integer }
---@param prop? { model: string|integer, bone?: integer, pos?: vector3, rot?: vector3 } held while the bar runs
---@return boolean|nil completed; nil when another action was already running
function FD.Actions.Run(label, duration, anim, prop)
    if busy then
        return nil
    end

    busy = true
    local completed = Bridge.Progress({
        label = tostring(label or locale('actions.default')),
        duration = tonumber(duration) or 5000,
        anim = anim or DEFAULT_ANIM,
        prop = prop,
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
