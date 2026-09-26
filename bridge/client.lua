--[[
    Client integration wrappers: notify, progress, target, clothing. Open file —
    swap any implementation here to match the resources installed on your server.
]]

local config = require('config.client')

Bridge = Bridge or {}

-- Notify ---------------------------------------------------------------------

---@param message string
---@param kind? 'primary'|'success'|'error'
function Bridge.Notify(message, kind)
    if GetResourceState('cm-notification') == 'started' then
        exports['cm-notification']:Alert(locale('notify.title'), message, 5000, kind or 'info')
        return
    end
    Bridge.FrameworkNotify(message, kind or 'primary')
end

-- Progress -------------------------------------------------------------------

---Blocking progress bar. Must be called from a thread/handler (it yields).
---@param data { label: string, duration: integer, anim?: { dict: string, clip: string, flag?: integer } }
---@return boolean completed
function Bridge.Progress(data)
    return lib.progressBar({
        label = data.label,
        duration = data.duration,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = data.anim,
    })
end

-- Clothing -------------------------------------------------------------------

function Bridge.OpenClothing()
    TriggerEvent(config.clothing.openEvent)
end

-- Target (qb-target API; ox_target also accepts it through its compatibility layer) ----

Bridge.Target = {}

local function targetResource()
    return config.targetResource
end

---@param options TargetOption[]
local function toTargetOptions(options)
    local mapped = {}
    for index, option in ipairs(options) do
        mapped[index] = {
            icon = option.icon,
            label = option.label,
            canInteract = option.canInteract and function(entity, distance)
                return option.canInteract(entity, distance)
            end,
            -- run in a thread so onSelect may yield (progress bars, callbacks)
            action = function(entity)
                CreateThread(function()
                    option.onSelect(entity)
                end)
            end,
        }
    end
    return mapped
end

---@return boolean
function Bridge.Target.IsReady()
    return GetResourceState(targetResource()) == 'started'
end

---@param entity integer
---@param options TargetOption[]
---@param distance number
function Bridge.Target.AddEntity(entity, options, distance)
    exports[targetResource()]:AddTargetEntity(entity, {
        options = toTargetOptions(options),
        distance = distance,
    })
end

---@param models string[]
---@param options TargetOption[]
---@param distance number
function Bridge.Target.AddModel(models, options, distance)
    local hashes = {}
    for index, model in ipairs(models) do
        hashes[index] = joaat(model)
    end
    exports[targetResource()]:AddTargetModel(hashes, {
        options = toTargetOptions(options),
        distance = distance,
    })
end

---@param name string
---@param coords vector3
---@param radius number
---@param options TargetOption[]
---@param distance number
function Bridge.Target.AddCircleZone(name, coords, radius, options, distance)
    exports[targetResource()]:AddCircleZone(name, coords, radius, { name = name, useZ = true }, {
        options = toTargetOptions(options),
        distance = distance,
    })
end

---@param name string
function Bridge.Target.RemoveZone(name)
    exports[targetResource()]:RemoveZone(name)
end
