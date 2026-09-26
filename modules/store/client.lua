--[[
    Store holdup (client): clerk peds, aim-to-surrender, register/shelf/safe targets
    and the safe keypad flow.
]]

local sharedConfig = require('config.shared')
local config = require('config.client')

local STORE <const> = 'store'
local SAFE_ANIM <const> = { dict = 'mini@safe_cracking', clip = 'idle_base', flag = 49 }

---@type table<integer, integer> store id -> clerk ped
local clerks = {}
---@type integer|nil store whose clerk surrendered
local armedStore = nil
local aimStartedAt = 0

---@param storeId integer
---@return boolean
local function isArmed(storeId)
    return FD.Mission.Is(STORE) and armedStore == storeId
end

---@param storeId integer
---@param kind 'register'|'shelf'
---@param index integer
local function loot(storeId, kind, index)
    if not isArmed(storeId) then
        return Bridge.Notify(locale('store.aim_first'), 'error')
    end

    local label = kind == 'register' and locale('store.emptying_register') or locale('store.collecting_shelf')
    local duration = kind == 'register' and config.store.registerTime or config.store.shelfTime
    if FD.Actions.Run(label, duration) then
        TriggerServerEvent(FD.Events.Server.StoreAction, storeId, kind, index)
    end
end

---@param storeId integer
local function openSafe(storeId)
    if not isArmed(storeId) then
        return Bridge.Notify(locale('store.control_first'), 'error')
    end

    local ok, hint, label = lib.callback.await(FD.Events.Callback.GetSafeHint, false, storeId)
    if not ok then
        return
    end

    if not FD.Nui.Focus(true) then
        return
    end
    FD.Nui.Send('safeInput', { storeId = storeId, hint = hint, label = label })
end

---@param storeId integer
---@param code string
local function crackSafe(storeId, code)
    if not FD.Mission.Is(STORE) or not sharedConfig.stores[storeId] then
        return
    end
    if FD.Actions.Run(locale('store.opening_safe'), config.store.safeTime, SAFE_ANIM) then
        TriggerServerEvent(FD.Events.Server.StoreAction, storeId, 'safe', 1, code)
    end
end

---@param storeId integer
---@param store table
local function addStoreZones(storeId, store)
    local function canInteract()
        return isArmed(storeId)
    end

    for index, coords in ipairs(store.registers or {}) do
        local name = ('je_store_%s_reg_%s'):format(storeId, index)
        Bridge.Target.AddCircleZone(name, coords, config.store.registerZoneRadius, {
            {
                icon = 'fas fa-cash-register',
                label = locale('target.store_register'),
                canInteract = canInteract,
                onSelect = function()
                    loot(storeId, 'register', index)
                end,
            },
        }, config.store.registerTargetDistance)
    end

    for index, coords in ipairs(store.shelves or {}) do
        local name = ('je_store_%s_shelf_%s'):format(storeId, index)
        Bridge.Target.AddCircleZone(name, coords, config.store.shelfZoneRadius, {
            {
                icon = 'fas fa-money-bill-wave',
                label = locale('target.store_shelf'),
                canInteract = canInteract,
                onSelect = function()
                    loot(storeId, 'shelf', index)
                end,
            },
        }, config.store.lootTargetDistance)
    end

    Bridge.Target.AddCircleZone(('je_store_%s_safe'):format(storeId), store.safe, config.store.safeZoneRadius, {
        {
            icon = 'fas fa-vault',
            label = locale('target.store_safe'),
            canInteract = canInteract,
            onSelect = function()
                openSafe(storeId)
            end,
        },
    }, config.store.lootTargetDistance)
end

local function spawnClerks()
    local model = lib.requestModel(config.store.clerkModel, 10000)
    for storeId, store in ipairs(sharedConfig.stores) do
        local pos = store.ped
        local clerk = CreatePed(4, model, pos.x, pos.y, pos.z - 1.0, pos.w, false, true)
        SetEntityInvincible(clerk, true)
        FreezeEntityPosition(clerk, true)
        SetBlockingOfNonTemporaryEvents(clerk, true)
        clerks[storeId] = clerk
        addStoreZones(storeId, store)
    end
    SetModelAsNoLongerNeeded(model)
end

---One pass of the aim check. Returns the wait time for the next pass.
---@return integer
local function checkAim()
    local player = cache.playerId
    local ped = cache.ped
    if not IsPedArmed(ped, 4) or not IsPlayerFreeAiming(player) then
        aimStartedAt = 0
        return 150
    end

    local origin = GetEntityCoords(ped)
    for storeId, clerk in pairs(clerks) do
        if
            DoesEntityExist(clerk)
            and #(origin - GetEntityCoords(clerk)) < config.store.aimDistance
            and IsPlayerFreeAimingAtEntity(player, clerk)
        then
            if armedStore ~= storeId then
                if aimStartedAt == 0 then
                    aimStartedAt = GetGameTimer()
                end
                if GetGameTimer() - aimStartedAt >= config.store.aimMilliseconds then
                    armedStore = storeId
                    TaskHandsUp(clerk, 600000, ped, -1, true)
                    Bridge.Notify(locale('store.clerk_surrendered'), 'success')
                    aimStartedAt = 0
                end
            end
            return 0
        end
    end

    return 150
end

FD.Mission.OnStart(function()
    armedStore = nil
end)

FD.Mission.OnEnd(function()
    armedStore = nil
end)

RegisterNUICallback('safeSubmit', function(data, cb)
    FD.Nui.Focus(false)
    cb('ok')
    local storeId, code = tonumber(data.storeId), tostring(data.code)
    if storeId then
        crackSafe(storeId, code)
    end
end)

RegisterNUICallback('safeCancel', function(_, cb)
    FD.Nui.Focus(false)
    cb('ok')
end)

CreateThread(function()
    while not Bridge.Target.IsReady() do
        Wait(500)
    end
    spawnClerks()
end)

CreateThread(function()
    while true do
        if FD.Mission.Is(STORE) then
            Wait(checkAim())
        else
            aimStartedAt = 0
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= FD.Resource then
        return
    end
    for _, clerk in pairs(clerks) do
        if DoesEntityExist(clerk) then
            DeleteEntity(clerk)
        end
    end
end)
