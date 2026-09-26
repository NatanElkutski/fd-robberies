--[[
    ATM breach (client) — rope + vehicle method:
    attach rope to the ATM (hook in hand) → attach hook to a vehicle (E) → N hard pulls →
    tow the ripped ATM away → stop to set it down → every crew member loots their share.
]]

local config = require('config.client')

local rope = config.atm.rope
local VEHICLE_REAR_OFFSET <const> = vec3(0.0, -2.2, 0.3)
local TOW_OFFSET <const> = vec3(0.0, -4.4, -0.55)
local DROP_OFFSET <const> = vec3(0.0, -4.4, 0.8)
local HOOK_PROMPT_DISTANCE <const> = 2.6
local STOP_SPEED <const> = 0.45
local STOP_TO_DROP_MS <const> = 1500
local ROPE_REPAIR_MS <const> = 500
local RIGHT_HAND_BONE <const> = 57005

---@class RopeState
---@field atm integer
---@field origin vector3
---@field rope? integer             vehicle tow rope
---@field handRope? integer         rope between ATM and the hook in hand
---@field vehicle? integer
---@field pulls integer
---@field pullReady boolean
---@field pullResetSince? integer
---@field lastPullAnchor vector3
---@field detached boolean
---@field towAttached? boolean
---@field lootable boolean
---@field stopSince? integer
---@field lastRopeRepair? integer

---@type RopeState|nil
local state = nil
local towHook = nil

local function loadRopeTextures()
    RopeLoadTextures()
    local deadline = GetGameTimer() + 2000
    while not RopeAreTexturesLoaded() and GetGameTimer() < deadline do
        Wait(0)
    end
end

local function removeTowHook()
    if towHook and DoesEntityExist(towHook) then
        DeleteEntity(towHook)
    end
    towHook = nil
end

local function giveTowHook()
    removeTowHook()
    local model = joaat(rope.hookModel)
    RequestModel(model)
    local deadline = GetGameTimer() + 2500
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not HasModelLoaded(model) then
        return
    end

    local ped = cache.ped
    towHook = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(
        towHook,
        ped,
        GetPedBoneIndex(ped, RIGHT_HAND_BONE),
        0.12,
        0.02,
        -0.02,
        -80.0,
        10.0,
        10.0,
        true,
        true,
        false,
        true,
        1,
        true
    )
    SetModelAsNoLongerNeeded(model)
end

---@param from integer entity
---@param fromPos vector3
---@param to integer entity
---@param toPos vector3
---@return integer rope handle
local function addRope(from, fromPos, to, toPos)
    local handle = AddRope(
        fromPos.x,
        fromPos.y,
        fromPos.z,
        0.0,
        0.0,
        0.0,
        rope.ropeLength,
        4,
        rope.ropeLength,
        1.0,
        0.5,
        false,
        false,
        true,
        1.0,
        false,
        0
    )
    AttachRopeToEntity(handle, from, fromPos.x, fromPos.y, fromPos.z, false)
    AttachRopeToEntity(handle, to, toPos.x, toPos.y, toPos.z, false)
    RopeForceLength(handle, rope.ropeLength)
    return handle
end

---@param rs RopeState
---@return boolean
local function createTowRope(rs)
    if not DoesEntityExist(rs.atm) or not rs.vehicle or not DoesEntityExist(rs.vehicle) then
        return false
    end
    if rs.rope and DoesRopeExist(rs.rope) then
        DeleteRope(rs.rope)
    end

    loadRopeTextures()
    local atmPos = GetEntityCoords(rs.atm) + vec3(0.0, 0.0, 0.45)
    local rear = GetOffsetFromEntityInWorldCoords(
        rs.vehicle,
        VEHICLE_REAR_OFFSET.x,
        VEHICLE_REAR_OFFSET.y,
        VEHICLE_REAR_OFFSET.z
    )
    rs.rope = addRope(rs.atm, atmPos, rs.vehicle, rear)
    return true
end

---@param rs RopeState
---@param finalPull boolean
local function pullEffects(rs, finalPull)
    if not DoesEntityExist(rs.atm) then
        return
    end

    local pos = GetEntityCoords(rs.atm)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', finalPull and 0.28 or 0.14)

    RequestNamedPtfxAsset('core')
    local deadline = GetGameTimer() + 1200
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < deadline do
        Wait(0)
    end
    if HasNamedPtfxAssetLoaded('core') then
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord(
            'ent_dst_concrete_large',
            pos.x,
            pos.y,
            pos.z + 0.35,
            0.0,
            0.0,
            0.0,
            finalPull and 1.15 or 0.65,
            false,
            false,
            false
        )
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord(
            'ent_dst_elec_fire_sp',
            pos.x,
            pos.y,
            pos.z + 0.65,
            0.0,
            0.0,
            0.0,
            finalPull and 0.9 or 0.45,
            false,
            false,
            false
        )
    end

    SetEntityVelocity(rs.atm, 0.0, 0.0, finalPull and 0.22 or 0.08)
end

---@param coords vector3
---@param text string
local function drawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then
        return
    end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 140, 0, 235)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Stage 1: walk to the back of a vehicle and press E to attach the hook.
---@param rs RopeState
local function tickAttachHook(rs)
    local ped = cache.ped
    local pedPos = GetEntityCoords(ped)
    local vehicle = Bridge.GetClosestVehicle(pedPos)
    if not vehicle or vehicle == 0 or #(pedPos - GetEntityCoords(vehicle)) >= rope.vehicleAttachDistance then
        return
    end

    local rear =
        GetOffsetFromEntityInWorldCoords(vehicle, VEHICLE_REAR_OFFSET.x, VEHICLE_REAR_OFFSET.y, VEHICLE_REAR_OFFSET.z)
    if #(pedPos - rear) >= HOOK_PROMPT_DISTANCE then
        return
    end

    DrawMarker(
        2,
        rear.x,
        rear.y,
        rear.z + 0.3,
        0,
        0,
        0,
        0,
        180.0,
        0,
        0.18,
        0.18,
        0.18,
        255,
        140,
        0,
        210,
        false,
        true,
        2
    )
    drawText3D(vec3(rear.x, rear.y, rear.z + 0.55), locale('atm.attach_hook_prompt'))

    if IsControlJustPressed(0, 38) then
        FD.Atm.RequestControl(vehicle)
        rs.vehicle = vehicle
        if rs.handRope and DoesRopeExist(rs.handRope) then
            DeleteRope(rs.handRope)
        end
        rs.handRope = nil
        removeTowHook()
        createTowRope(rs)
        Bridge.Notify(locale('atm.hook_attached', rope.pullCount), 'success')
    end
end

---@param rs RopeState
local function ripFromWall(rs)
    FD.Atm.RequestControl(rs.atm)
    if IsEntityAttached(rs.atm) then
        DetachEntity(rs.atm, true, true)
    end
    FreezeEntityPosition(rs.atm, false)
    SetEntityDynamic(rs.atm, true)
    ActivatePhysics(rs.atm)
    SetEntityCollision(rs.atm, true, true)
    SetEntityHasGravity(rs.atm, true)

    local back = GetEntityForwardVector(rs.vehicle)
    ApplyForceToEntity(rs.atm, 1, -back.x * 5.0, -back.y * 5.0, 0.8, 0, 0, 0, 0, false, true, true, false, true)
    Wait(650)

    rs.detached = true
    rs.lastRopeRepair = 0
    createTowRope(rs)
    Bridge.Notify(locale('atm.ripped'), 'success')
end

-- Stage 2: count hard pulls; the driver must slow down between pulls.
---@param rs RopeState
local function tickPulls(rs)
    local speed = GetEntitySpeed(rs.vehicle)
    local moved = #(GetEntityCoords(rs.vehicle) - (rs.lastPullAnchor or rs.origin))

    if rs.pullReady and speed > rope.pullSpeed and moved >= rope.pullDistance then
        rs.pulls += 1
        rs.pullReady = false
        rs.pullResetSince = nil
        pullEffects(rs, rs.pulls >= rope.pullCount)

        if rs.pulls < rope.pullCount then
            Bridge.Notify(locale('atm.pull_ok', rs.pulls, rope.pullCount), 'primary')
        else
            Bridge.Notify(locale('atm.pull_final', rs.pulls, rope.pullCount), 'success')
            ripFromWall(rs)
        end
        return
    end

    if rs.pullReady or rs.pulls >= rope.pullCount then
        return
    end

    if speed < rope.pullResetSpeed then
        rs.pullResetSince = rs.pullResetSince or GetGameTimer()
        if GetGameTimer() - rs.pullResetSince >= rope.pullResetMs then
            rs.pullReady = true
            rs.pullResetSince = nil
            rs.lastPullAnchor = GetEntityCoords(rs.vehicle)
            Bridge.Notify(locale('atm.pull_ready', rs.pulls, rope.pullCount), 'primary')
        end
    else
        rs.pullResetSince = nil
    end
end

---@param rs RopeState
local function setDown(rs)
    if IsEntityAttached(rs.atm) then
        DetachEntity(rs.atm, true, true)
    end
    rs.towAttached = false
    SetEntityCollision(rs.atm, true, true)
    SetEntityHasGravity(rs.atm, true)
    SetEntityDynamic(rs.atm, true)

    local drop = GetOffsetFromEntityInWorldCoords(rs.vehicle, DROP_OFFSET.x, DROP_OFFSET.y, DROP_OFFSET.z)
    SetEntityCoordsNoOffset(rs.atm, drop.x, drop.y, drop.z, false, false, false)
    PlaceObjectOnGroundProperly(rs.atm)
    SetEntityVelocity(rs.atm, 0.0, 0.0, 0.0)
    Wait(100)
    PlaceObjectOnGroundProperly(rs.atm)
    FreezeEntityPosition(rs.atm, true)

    rs.lootable = true
    FD.Atm.crewRopeLootable = true
    TriggerServerEvent(FD.Events.Server.RopeLootable, FD.Atm.crewRopeNetId)
    Bridge.Notify(locale('atm.dropped'), 'success')
end

-- Stage 3: the ripped ATM is hard-attached behind the vehicle (GTA rope physics would
-- tunnel it under the road); stopping far enough away sets it down for looting.
---@param rs RopeState
local function tickTow(rs)
    if not rs.vehicle or not DoesEntityExist(rs.vehicle) or not DoesEntityExist(rs.atm) then
        return
    end

    FD.Atm.RequestControl(rs.atm)
    if rs.lootable then
        return
    end

    if not rs.towAttached or not IsEntityAttachedToEntity(rs.atm, rs.vehicle) then
        if IsEntityAttached(rs.atm) then
            DetachEntity(rs.atm, true, true)
        end
        FreezeEntityPosition(rs.atm, false)
        SetEntityDynamic(rs.atm, true)
        SetEntityCollision(rs.atm, false, false)
        SetEntityHasGravity(rs.atm, false)
        AttachEntityToEntity(
            rs.atm,
            rs.vehicle,
            0,
            TOW_OFFSET.x,
            TOW_OFFSET.y,
            TOW_OFFSET.z,
            0.0,
            0.0,
            0.0,
            false,
            false,
            false,
            false,
            2,
            true
        )
        rs.towAttached = true
    end

    local now = GetGameTimer()
    if not rs.rope or not DoesRopeExist(rs.rope) then
        if now - (rs.lastRopeRepair or 0) > ROPE_REPAIR_MS then
            rs.lastRopeRepair = now
            createTowRope(rs)
        end
    else
        RopeForceLength(rs.rope, rope.ropeLength)
    end

    if #(GetEntityCoords(rs.atm) - rs.origin) < rope.lootDistanceFromOrigin then
        return
    end

    if GetEntitySpeed(rs.vehicle) < STOP_SPEED then
        rs.stopSince = rs.stopSince or now
    else
        rs.stopSince = nil
    end

    if rs.stopSince and now - rs.stopSince >= STOP_TO_DROP_MS then
        setDown(rs)
    end
end

FD.Atm.Rope = {}

---@param entity integer
---@return boolean
function FD.Atm.Rope.IsAttachedTo(entity)
    return state ~= nil and state.atm == entity
end

function FD.Atm.Rope.Cleanup()
    removeTowHook()
    if state then
        if state.rope and DoesRopeExist(state.rope) then
            DeleteRope(state.rope)
        end
        if state.handRope and DoesRopeExist(state.handRope) then
            DeleteRope(state.handRope)
        end
        if state.atm and DoesEntityExist(state.atm) then
            if IsEntityAttached(state.atm) then
                DetachEntity(state.atm, true, true)
            end
            FreezeEntityPosition(state.atm, true)
        end
    end
    state = nil
end

---@param entity integer
function FD.Atm.Rope.Start(entity)
    if state then
        return Bridge.Notify(locale('atm.rope_already'), 'error')
    end

    local ok, message = lib.callback.await(FD.Events.Callback.CheckMethod, false, 'rope')
    if not ok then
        return Bridge.Notify(message or locale('atm.missing_rope'), 'error')
    end

    if not FD.Actions.Run(locale('atm.attaching_rope'), config.atm.methodTime.rope) or not DoesEntityExist(entity) then
        return
    end

    TriggerServerEvent(FD.Events.Server.ConsumeAtmItem, 'rope')
    FD.Atm.RequestControl(entity)
    local origin = GetEntityCoords(entity)
    loadRopeTextures()

    state = {
        atm = entity,
        origin = origin,
        pulls = 0,
        pullReady = true,
        lastPullAnchor = origin,
        detached = false,
        lootable = false,
    }
    FD.Atm.used[entity] = true

    giveTowHook()
    if towHook and DoesEntityExist(towHook) then
        state.handRope = addRope(entity, origin + vec3(0.0, 0.0, 0.5), towHook, GetEntityCoords(towHook))
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    SetNetworkIdCanMigrate(netId, true)
    FD.Atm.crewRopeNetId = netId
    TriggerServerEvent(FD.Events.Server.RegisterRopeAtm, netId)
    Bridge.Notify(locale('atm.rope_attached'), 'success')
end

---Loot the ripped ATM (every crew member takes a share).
---@param entity integer
function FD.Atm.Rope.Loot(entity)
    if not entity or entity == 0 then
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not FD.Atm.IsActive() or not FD.Atm.crewRopeNetId or netId ~= FD.Atm.crewRopeNetId then
        return Bridge.Notify(locale('atm.not_yours'), 'error')
    end
    if state and state.atm == entity and not state.lootable then
        return Bridge.Notify(locale('atm.tow_further'), 'error')
    end
    if not FD.Atm.IsNear(entity, config.atm.lootDistance) then
        return
    end

    if FD.Actions.Run(locale('atm.opening_towed'), config.atm.towedLootTime) then
        TriggerServerEvent(FD.Events.Server.RopeLoot, netId)
    end
end

RegisterNetEvent(FD.Events.Client.CrewRopeAtm, function(netId)
    FD.Atm.crewRopeNetId = tonumber(netId)
    FD.Atm.crewRopeLootable = false
end)

RegisterNetEvent(FD.Events.Client.CrewRopeLootable, function(netId)
    if FD.Atm.crewRopeNetId == tonumber(netId) then
        FD.Atm.crewRopeLootable = true
    end
end)

RegisterNetEvent(FD.Events.Client.DetachRopeAfterLoot, function(netId)
    netId = tonumber(netId)
    if FD.Atm.crewRopeNetId ~= netId or not state or not state.atm then
        return
    end
    if NetworkGetNetworkIdFromEntity(state.atm) ~= netId then
        return
    end

    if state.rope and DoesRopeExist(state.rope) then
        DeleteRope(state.rope)
    end
    state.rope = nil

    if DoesEntityExist(state.atm) then
        FD.Atm.RequestControl(state.atm)
        if IsEntityAttached(state.atm) then
            DetachEntity(state.atm, true, true)
        end
        FreezeEntityPosition(state.atm, false)
        SetEntityDynamic(state.atm, true)
        ActivatePhysics(state.atm)
    end

    state.vehicle = nil
    Bridge.Notify(locale('atm.rope_released'), 'success')
end)

RegisterNetEvent(FD.Events.Client.RopeAllLooted, function(netId)
    if FD.Atm.crewRopeNetId == tonumber(netId) then
        Bridge.Notify(locale('atm.all_looted'), 'success')
    end
end)

RegisterNetEvent(FD.Events.Client.LootTowedAtm, function(data)
    FD.Atm.Rope.Loot(type(data) == 'table' and data.entity or data)
end)

CreateThread(function()
    while true do
        local rs = state
        if rs and FD.Atm.IsActive() then
            Wait(0)
            if not rs.vehicle then
                tickAttachHook(rs)
            elseif not rs.detached and DoesEntityExist(rs.vehicle) then
                tickPulls(rs)
            elseif rs.detached then
                tickTow(rs)
            end
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == FD.Resource then
        FD.Atm.Rope.Cleanup()
    end
end)
