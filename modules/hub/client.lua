--[[
    Hub (client): the robbery menu (command/key/NPC), the contact NPC and its
    target options (menu, finish contract, robbery outfit, clothing).
]]

local sharedConfig = require('config.shared')
local config = require('config.client')

local hubPed = nil

FD.Hub = {}

---Robbery cards for the NUI: shared definition + translated text + XP from the server.
---@param xpRewards table<string, integer>
local function catalogue(xpRewards)
    local robberies = {}
    for id, robbery in pairs(sharedConfig.robberies) do
        robberies[id] = {
            label = locale(('robbery.%s.label'):format(id)),
            subtitle = locale(('robbery.%s.subtitle'):format(id)),
            level = robbery.level,
            minPolice = robbery.minPolice,
            duration = robbery.duration,
            minPlayers = robbery.crew.min,
            maxPlayers = robbery.crew.max,
            xpReward = xpRewards[id] or 0,
        }
    end
    return robberies
end

function FD.Hub.Open()
    local data = lib.callback.await(FD.Events.Callback.GetData, false)
    if not data then
        return
    end

    if not FD.Nui.Focus(true) then
        return
    end
    FD.Nui.Send('open', {
        config = catalogue(data.xpRewards or {}),
        data = data,
        shop = data.shop,
        nearby = FD.Crew.Nearby(),
        locale = FD.Locale.All(),
    })
end

local function wearOutfit()
    local ped = cache.ped
    local gender = GetEntityModel(ped) == `mp_f_freemode_01` and 'female' or 'male'
    for _, piece in ipairs(config.clothing.outfits[gender] or {}) do
        SetPedComponentVariation(ped, piece.component, piece.drawable, piece.texture or 0, 0)
    end
    Bridge.Notify(locale('hub.outfit_worn'), 'success')
end

---@return TargetOption[]
local function npcOptions()
    local options = {
        { icon = 'fas fa-mask', label = locale('target.open_menu'), onSelect = FD.Hub.Open },
        {
            icon = 'fas fa-flag-checkered',
            label = locale('target.exit_contract'),
            canInteract = function()
                return FD.Mission.Current() ~= nil
            end,
            onSelect = function()
                TriggerServerEvent(FD.Events.Server.ExitMission)
            end,
        },
    }

    if config.clothing.enabled then
        options[#options + 1] =
            { icon = 'fas fa-user-secret', label = locale('target.wear_outfit'), onSelect = wearOutfit }
        options[#options + 1] =
            { icon = 'fas fa-shirt', label = locale('target.clothing'), onSelect = Bridge.OpenClothing }
    end

    return options
end

local function spawnNpc()
    local npc = config.hubNpc
    local model = lib.requestModel(npc.model, 10000)
    hubPed = CreatePed(4, model, npc.coords.x, npc.coords.y, npc.coords.z, npc.coords.w, false, true)
    SetModelAsNoLongerNeeded(model)

    SetEntityInvincible(hubPed, npc.invincible)
    FreezeEntityPosition(hubPed, npc.frozen)
    SetBlockingOfNonTemporaryEvents(hubPed, npc.blockEvents)
    TaskStartScenarioInPlace(hubPed, npc.scenario, 0, true)

    Bridge.Target.AddEntity(hubPed, npcOptions(), npc.targetDistance)
end

RegisterCommand(config.openCommand, function()
    CreateThread(FD.Hub.Open)
end, false)
RegisterKeyMapping(config.openCommand, locale('keys.open_hub'), 'keyboard', config.openKey)

CreateThread(function()
    while not Bridge.Target.IsReady() do
        Wait(500)
    end
    if config.hubNpc.enabled then
        spawnNpc()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == FD.Resource and hubPed and DoesEntityExist(hubPed) then
        DeleteEntity(hubPed)
    end
end)
