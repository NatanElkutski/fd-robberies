--[[
    ATM breach (client) — entry point: ATM targets, the method menu (NUI) and
    per-contract reset. Dispatches to the rope / drill / explosive role files.
]]

local config = require('config.client')

---@type integer|nil ATM entity the method menu was opened for
local selectedAtm = nil
---@type table<string, true> close-range zones already created (by entity handle)
local closeZones = {}

local METHODS = {
    rope = function(entity)
        FD.Atm.Rope.Start(entity)
    end,
    drill = function(entity)
        FD.Atm.Drill.Start(entity)
    end,
    explosive = function(entity)
        FD.Atm.Explosive.Start(entity)
    end,
}

---@param method string
---@param entity integer
local function runMethod(method, entity)
    if not FD.Atm.IsActive() then
        return
    end
    if FD.Atm.used[entity] then
        return Bridge.Notify(locale('atm.in_use'), 'error')
    end

    local start = METHODS[method]
    if start then
        start(entity)
    end
end

---@param entity integer
local function openMenu(entity)
    if not FD.Atm.IsActive() then
        return Bridge.Notify(locale('atm.no_active'), 'error')
    end
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return Bridge.Notify(locale('atm.not_found'), 'error')
    end
    if not FD.Atm.IsNear(entity, config.atm.targetDistance + 0.5) then
        return Bridge.Notify(locale('atm.too_far'), 'error')
    end
    if FD.Atm.used[entity] then
        return Bridge.Notify(locale('atm.in_use'), 'error')
    end

    if not FD.Nui.Focus(true) then
        return
    end
    selectedAtm = entity
    FD.Nui.Send('atmMenu', { show = true })
end

---@param entity integer
---@return boolean
local function canBreach(entity)
    return FD.Atm.IsActive() and not FD.Atm.Rope.IsAttachedTo(entity)
end

---@param entity integer
---@return boolean
local function canLootTowed(entity)
    return FD.Atm.IsActive()
        and FD.Atm.crewRopeNetId ~= nil
        and FD.Atm.crewRopeLootable
        and NetworkGetNetworkIdFromEntity(entity) == FD.Atm.crewRopeNetId
end

---@param entity integer
---@return boolean
local function canLootBlasted(entity)
    return FD.Atm.IsActive() and FD.Atm.blasted == entity
end

---Target options for one ATM. `maxDistance` limits the model target; zones pass nil.
---@param maxDistance? number
---@return TargetOption[]
local function atmOptions(maxDistance)
    local function inRange(distance, limit)
        return not maxDistance or not distance or distance <= limit
    end

    return {
        {
            icon = 'fas fa-screwdriver-wrench',
            label = locale('target.atm_methods'),
            canInteract = function(entity, distance)
                return canBreach(entity) and inRange(distance, (maxDistance or 0) + 0.25)
            end,
            onSelect = openMenu,
        },
        {
            icon = 'fas fa-money-bill-wave',
            label = locale('target.atm_loot_towed'),
            canInteract = function(entity, distance)
                return canLootTowed(entity) and inRange(distance, config.atm.lootDistance)
            end,
            onSelect = FD.Atm.Rope.Loot,
        },
        {
            icon = 'fas fa-money-bill-wave',
            label = locale('target.atm_loot_blasted'),
            canInteract = function(entity, distance)
                return canLootBlasted(entity) and inRange(distance, config.atm.lootDistance)
            end,
            onSelect = FD.Atm.Explosive.Loot,
        },
    }
end

---Zone options bound to a specific ATM entity (zones don't pass the entity).
---@param entity integer
---@return TargetOption[]
local function zoneOptionsFor(entity)
    local options = atmOptions(nil)
    for _, option in ipairs(options) do
        local canInteract, onSelect = option.canInteract, option.onSelect
        option.canInteract = function()
            return canInteract(entity)
        end
        option.onSelect = function()
            onSelect(entity)
        end
    end
    return options
end

-- Model targets can be hard to hit with the camera pressed against the ATM, so while an
-- ATM contract is active, nearby ATMs also get a small zone overlapping the prop itself.
local function addCloseZones()
    local origin = GetEntityCoords(cache.ped)
    for _, model in ipairs(config.atm.models) do
        local entity = GetClosestObjectOfType(
            origin.x,
            origin.y,
            origin.z,
            config.atm.closeZoneScanRadius,
            joaat(model),
            false,
            false,
            false
        )
        if entity ~= 0 and DoesEntityExist(entity) and not closeZones[tostring(entity)] then
            local name = ('je_atm_close_%s'):format(entity)
            Bridge.Target.AddCircleZone(
                name,
                GetEntityCoords(entity),
                config.atm.closeTargetRadius,
                zoneOptionsFor(entity),
                config.atm.targetDistance + 0.25
            )
            closeZones[tostring(entity)] = true
        end
    end
end

FD.Mission.OnStart(function()
    FD.Atm.used = {}
    FD.Atm.blasted = nil
    FD.Atm.Rope.Cleanup()
end)

FD.Mission.OnEnd(function()
    FD.Atm.blasted = nil
    FD.Atm.Rope.Cleanup()
    FD.Atm.crewRopeNetId = nil
    FD.Atm.crewRopeLootable = false
end)

RegisterNetEvent(FD.Events.Client.OpenAtmMethods, function(data)
    openMenu(type(data) == 'table' and data.entity or data)
end)

RegisterNUICallback('atmChoose', function(data, cb)
    local entity = selectedAtm
    selectedAtm = nil
    FD.Nui.Focus(false)
    FD.Nui.Send('atmMenu', { show = false })
    cb('ok')

    if entity and DoesEntityExist(entity) and data?.method then
        runMethod(data.method, entity)
    end
end)

RegisterNUICallback('atmCancel', function(_, cb)
    selectedAtm = nil
    FD.Nui.Focus(false)
    FD.Nui.Send('atmMenu', { show = false })
    cb('ok')
end)

CreateThread(function()
    while not Bridge.Target.IsReady() do
        Wait(500)
    end
    Bridge.Target.AddModel(config.atm.models, atmOptions(config.atm.targetDistance), config.atm.targetDistance)
end)

CreateThread(function()
    while true do
        if FD.Atm.IsActive() and Bridge.Target.IsReady() then
            addCloseZones()
            Wait(1000)
        else
            Wait(1500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= FD.Resource then
        return
    end
    for key in pairs(closeZones) do
        Bridge.Target.RemoveZone(('je_atm_close_%s'):format(key))
    end
end)
