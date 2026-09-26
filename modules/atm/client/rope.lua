--[[
    ATM breach (client) — rope + vehicle method. Stages:

      hand      rope tied to the wall ATM, hook in the player's hand → press E at a vehicle's rear
      anchored  rope wall ATM ↔ vehicle; the driver does N hard pulls (stop between pulls)
      towing    the ATM breaks off: the map ATM is hidden for everyone and replaced by a networked,
                fully physical ATM prop tied to the vehicle with a real rope — it falls, drags,
                bounces and throws sparks. A watchdog puts it back behind the car if physics lose it.
      loose     the vehicle was lost (deleted/destroyed) before the loot distance → re-hook to a vehicle
      lootable  the vehicle stopped far enough away: rope unhooked, ATM settles, every member loots

    Only the player who ripped the ATM runs the physics (owns the prop). The rest of the crew gets a
    mirrored visual rope (CrewRopeTow) and loots through FD.Atm.Rope.Loot.
]]

local config = require('config.client')

local rope = config.atm.rope
local ROPE_TYPE <const> = 4
local VEHICLE_REAR_OFFSET <const> = vec3(0.0, -2.2, 0.3)
local HOOK_PROMPT_DISTANCE <const> = 2.6
local STOP_SPEED <const> = 0.45
local SETTLE_SPEED <const> = 0.3
local SETTLE_TIMEOUT_MS <const> = 3000
local SPARK_INTERVAL_MS <const> = 120
local WATCHDOG_INTERVAL_MS <const> = 400
local RIGHT_HAND_BONE <const> = 57005
local LOOT_ANIM <const> = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'grab', flag = 1 }
local CONTROL_E <const> = 38

---@class RopeState
---@field stage 'hand'|'anchored'|'towing'|'loose'|'lootable'
---@field wallAtm integer            the map ATM (never networked)
---@field model integer
---@field origin vector3
---@field prop? integer              networked ATM prop after the rip
---@field netId? integer
---@field vehicle? integer
---@field rope? integer              current rope (wall↔vehicle or prop↔vehicle)
---@field handRope? integer          rope wall ATM ↔ hook in hand
---@field pulls integer
---@field pullReady boolean
---@field pullResetSince? integer
---@field lastPullAnchor vector3
---@field stopSince? integer
---@field nextSpark integer
---@field nextWatchdog integer

---@type RopeState|nil
local state = nil
local towHook = nil
---@type integer|nil visual rope mirrored from another crew member's tow
local crewRope = nil

-- Helpers ----------------------------------------------------------------------

local function loadRopeTextures()
    RopeLoadTextures()
    local deadline = GetGameTimer() + 2000
    while not RopeAreTexturesLoaded() and GetGameTimer() < deadline do
        Wait(0)
    end
end

---@param handle? integer
local function deleteRope(handle)
    if handle and DoesRopeExist(handle) then
        DeleteRope(handle)
    end
end

---Rope tied between two entities at the given world positions.
---@return integer rope handle
local function tieRope(entityA, posA, entityB, posB, length)
    loadRopeTextures()
    local handle = AddRope(
        posA.x,
        posA.y,
        posA.z,
        0.0,
        0.0,
        0.0,
        length,
        ROPE_TYPE,
        length,
        1.0,
        0.5,
        false,
        false,
        true,
        1.0,
        false,
        0
    )
    AttachEntitiesToRope(
        handle,
        entityA,
        entityB,
        posA.x,
        posA.y,
        posA.z,
        posB.x,
        posB.y,
        posB.z,
        length,
        false,
        false,
        nil,
        nil
    )
    return handle
end

---@param vehicle integer
---@return vector3
local function rearOf(vehicle)
    return GetOffsetFromEntityInWorldCoords(
        vehicle,
        VEHICLE_REAR_OFFSET.x,
        VEHICLE_REAR_OFFSET.y,
        VEHICLE_REAR_OFFSET.z
    )
end

---@param entity integer
---@return vector3
local function topOf(entity)
    return GetEntityCoords(entity) + vec3(0.0, 0.0, 0.45)
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

---Closest vehicle whose rear the player is standing at (on foot), or nil.
---@return integer|nil vehicle
---@return vector3|nil rear
local function vehicleAtRear()
    if IsPedInAnyVehicle(cache.ped, false) then
        return
    end
    local pedPos = GetEntityCoords(cache.ped)
    local vehicle = Bridge.GetClosestVehicle(pedPos)
    if not vehicle or vehicle == 0 or #(pedPos - GetEntityCoords(vehicle)) >= rope.vehicleAttachDistance then
        return
    end
    local rear = rearOf(vehicle)
    if #(pedPos - rear) >= HOOK_PROMPT_DISTANCE then
        return
    end
    return vehicle, rear
end

---Shows the [E] prompt at a vehicle's rear; returns the vehicle when E is pressed.
---@return integer|nil
local function promptHookVehicle()
    local vehicle, rear = vehicleAtRear()
    if not vehicle or not rear then
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
    drawText3D(rear + vec3(0.0, 0.0, 0.55), locale('atm.attach_hook_prompt'))
    if IsControlJustPressed(0, CONTROL_E) then
        return vehicle
    end
end

---@param vehicle? integer
local function syncCrewRope(vehicle)
    TriggerServerEvent(FD.Events.Server.RopeTowSync, vehicle and FD.Atm.NetIdOf(vehicle) or nil)
end

-- Effects ------------------------------------------------------------------------

---@param pos vector3
---@param finalPull boolean
local function pullEffects(pos, finalPull)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', finalPull and 0.3 or 0.14)
    if FD.Atm.LoadPtfx('core') then
        FD.Atm.Burst('ent_dst_concrete_large', pos + vec3(0.0, 0.0, 0.35), finalPull and 1.2 or 0.65)
        FD.Atm.Burst('ent_dst_elec_fire_sp', pos + vec3(0.0, 0.0, 0.65), finalPull and 0.9 or 0.45)
    end
end

---Sparks while the ATM scrapes along the ground.
---@param rs RopeState
local function dragEffects(rs)
    local now = GetGameTimer()
    if now < rs.nextSpark then
        return
    end
    rs.nextSpark = now + SPARK_INTERVAL_MS

    if GetEntitySpeed(rs.prop) < rope.sparksMinSpeed or IsEntityInAir(rs.prop) then
        return
    end
    local pos = GetEntityCoords(rs.prop)
    FD.Atm.Burst('ent_dst_elec_fire_sp', vec3(pos.x, pos.y, pos.z - 0.2), 0.35)
end

-- Stage transitions ---------------------------------------------------------------------

---@param rs RopeState
---@param vehicle integer
local function anchorToVehicle(rs, vehicle)
    FD.Atm.RequestControl(vehicle)
    rs.vehicle = vehicle
    deleteRope(rs.handRope)
    rs.handRope = nil
    removeTowHook()
    rs.rope = tieRope(rs.wallAtm, topOf(rs.wallAtm), vehicle, rearOf(vehicle), rope.ropeLength)
    rs.stage = 'anchored'
    Bridge.Notify(locale('atm.hook_attached', rope.pullCount), 'success')
end

---@param rs RopeState
---@param vehicle integer
local function towWith(rs, vehicle)
    rs.vehicle = vehicle
    rs.stopSince = nil
    deleteRope(rs.rope)
    rs.rope = tieRope(rs.prop, topOf(rs.prop), vehicle, rearOf(vehicle), rope.towRopeLength)
    rs.stage = 'towing'
    syncCrewRope(vehicle)
end

---Replaces the static map ATM with a networked physical prop and throws it towards the vehicle.
---@param rs RopeState
---@return boolean ripped
local function ripFromWall(rs)
    local pos = GetEntityCoords(rs.wallAtm)
    local rot = GetEntityRotation(rs.wallAtm, 2)

    lib.requestModel(rs.model, 5000)
    local prop = CreateObjectNoOffset(rs.model, pos.x, pos.y, pos.z, true, true, false)
    SetModelAsNoLongerNeeded(rs.model)

    local deadline = GetGameTimer() + 2000
    while not NetworkGetEntityIsNetworked(prop) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not DoesEntityExist(prop) or not NetworkGetEntityIsNetworked(prop) then
        -- usually a server with strict entity lockdown (client-created entities blocked)
        print(('^1[%s] could not create a networked ATM prop (check sv_entityLockdown)^7'):format(FD.Resource))
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
        return false
    end

    FD.Atm.World.Hide(pos, rs.model)
    SetEntityRotation(prop, rot.x, rot.y, rot.z, 2, true)

    local netId = NetworkGetNetworkIdFromEntity(prop)
    SetNetworkIdCanMigrate(netId, false) -- the puller keeps simulating its physics
    SetNetworkIdExistsOnAllMachines(netId, true)

    FreezeEntityPosition(prop, false)
    SetEntityDynamic(prop, true)
    SetEntityHasGravity(prop, true)
    SetEntityCollision(prop, true, true)
    ActivatePhysics(prop)

    rs.prop = prop
    rs.netId = netId
    FD.Atm.crewRopeNetId = netId
    FD.Atm.used[prop] = true

    towWith(rs, rs.vehicle)

    -- break it off: tip it forward and throw it towards the vehicle
    local towards = GetEntityCoords(rs.vehicle) - pos
    local length = #towards
    if length > 0.01 then
        towards = towards / length
    end
    ApplyForceToEntityCenterOfMass(
        prop,
        1,
        towards.x * rope.ripImpulse,
        towards.y * rope.ripImpulse,
        2.5,
        false,
        false,
        true,
        false
    )

    TriggerServerEvent(FD.Events.Server.RegisterRopeAtm, netId, pos, rs.model)
    Bridge.Notify(locale('atm.ripped'), 'success')
    return true
end

---Waits for the ATM to stop moving, freezes it and makes it lootable for the crew.
---@param rs RopeState
local function makeLootable(rs)
    deleteRope(rs.rope)
    rs.rope = nil
    rs.vehicle = nil
    syncCrewRope(nil)

    local deadline = GetGameTimer() + SETTLE_TIMEOUT_MS
    while DoesEntityExist(rs.prop) and GetEntitySpeed(rs.prop) > SETTLE_SPEED and GetGameTimer() < deadline do
        Wait(100)
    end
    if DoesEntityExist(rs.prop) then
        FreezeEntityPosition(rs.prop, true)
    end

    rs.stage = 'lootable'
    FD.Atm.crewRopeLootable = true
    TriggerServerEvent(FD.Events.Server.RopeLootable, rs.netId)
    Bridge.Notify(locale('atm.dropped'), 'success')
end

---@param rs RopeState
---@return boolean
local function farEnough(rs)
    return #(GetEntityCoords(rs.prop) - rs.origin) >= rope.lootDistanceFromOrigin
end

---The vehicle is gone: the ATM stays where it is, lootable if far enough, otherwise re-hookable.
---@param rs RopeState
local function loseVehicle(rs)
    if farEnough(rs) then
        return makeLootable(rs)
    end
    deleteRope(rs.rope)
    rs.rope = nil
    rs.vehicle = nil
    rs.stage = 'loose'
    syncCrewRope(nil)
    Bridge.Notify(locale('atm.vehicle_lost'), 'error')
end

-- Per-frame stage logic ---------------------------------------------------------------------

---@param rs RopeState
local function tickHand(rs)
    local vehicle = promptHookVehicle()
    if vehicle then
        anchorToVehicle(rs, vehicle)
    end
end

---Counts hard pulls; the driver must slow down between pulls.
---@param rs RopeState
local function tickAnchored(rs)
    if not rs.vehicle or not DoesEntityExist(rs.vehicle) then
        deleteRope(rs.rope)
        rs.rope, rs.vehicle, rs.stage = nil, nil, 'hand'
        return
    end

    local speed = GetEntitySpeed(rs.vehicle)
    local moved = #(GetEntityCoords(rs.vehicle) - rs.lastPullAnchor)

    if rs.pullReady and speed > rope.pullSpeed and moved >= rope.pullDistance then
        rs.pulls += 1
        rs.pullReady = false
        rs.pullResetSince = nil
        local finalPull = rs.pulls >= rope.pullCount
        pullEffects(GetEntityCoords(rs.wallAtm), finalPull)

        if not finalPull then
            return Bridge.Notify(locale('atm.pull_ok', rs.pulls, rope.pullCount), 'primary')
        end

        Bridge.Notify(locale('atm.pull_final', rs.pulls, rope.pullCount), 'success')
        if not ripFromWall(rs) then
            -- could not spawn the physical ATM: let the crew try again
            rs.pulls = rope.pullCount - 1
            rs.pullReady = true
            Bridge.Notify(locale('atm.rip_failed'), 'error')
        end
        return
    end

    if rs.pullReady then
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

---Keeps the towed ATM with the vehicle when GTA physics lose it (fell through the road,
---snagged on a lamp post, rope snapped).
---@param rs RopeState
local function watchdog(rs)
    local now = GetGameTimer()
    if now < rs.nextWatchdog then
        return
    end
    rs.nextWatchdog = now + WATCHDOG_INTERVAL_MS

    local pos = GetEntityCoords(rs.prop)
    local found, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 3.0, false)
    local underGround = found and pos.z < groundZ - 1.0
    local tooFar = #(pos - GetEntityCoords(rs.vehicle)) > rope.towRopeLength + rope.rescueExtraDistance
    local ropeGone = not rs.rope or not DoesRopeExist(rs.rope)

    if underGround or tooFar then
        local behind = GetOffsetFromEntityInWorldCoords(rs.vehicle, 0.0, -(rope.towRopeLength * 0.6 + 2.0), 1.0)
        local _, z = GetGroundZFor_3dCoord(behind.x, behind.y, behind.z + 3.0, false)
        SetEntityCoordsNoOffset(rs.prop, behind.x, behind.y, (z ~= 0.0 and z or behind.z) + 0.6, false, false, false)
        local velocity = GetEntityVelocity(rs.vehicle)
        SetEntityVelocity(rs.prop, velocity.x, velocity.y, velocity.z)
        ropeGone = true
    end

    if ropeGone then
        towWith(rs, rs.vehicle)
    end
end

---@param rs RopeState
local function tickTowing(rs)
    if not DoesEntityExist(rs.prop) then
        return
    end
    if not rs.vehicle or not DoesEntityExist(rs.vehicle) or IsEntityDead(rs.vehicle) then
        return loseVehicle(rs)
    end

    dragEffects(rs)
    watchdog(rs)

    if not farEnough(rs) then
        rs.stopSince = nil
        return
    end

    if GetEntitySpeed(rs.vehicle) < STOP_SPEED then
        rs.stopSince = rs.stopSince or GetGameTimer()
        if GetGameTimer() - rs.stopSince >= rope.stopToDropMs then
            makeLootable(rs)
        end
    else
        rs.stopSince = nil
    end
end

---@param rs RopeState
local function tickLoose(rs)
    if not DoesEntityExist(rs.prop) or not FD.Atm.IsNear(rs.prop, rope.looseRehookDistance) then
        return
    end
    local vehicle = promptHookVehicle()
    if vehicle then
        towWith(rs, vehicle)
        Bridge.Notify(locale('atm.rehooked'), 'success')
    end
end

local TICKS = {
    hand = tickHand,
    anchored = tickAnchored,
    towing = tickTowing,
    loose = tickLoose,
}

-- Public API ------------------------------------------------------------------------

FD.Atm.Rope = {}

---True for the ATM this player is currently working on (wall ATM or its prop).
---@param entity integer
---@return boolean
function FD.Atm.Rope.IsAttachedTo(entity)
    return state ~= nil and (state.wallAtm == entity or state.prop == entity)
end

function FD.Atm.Rope.Cleanup()
    removeTowHook()
    deleteRope(crewRope)
    crewRope = nil
    if state then
        deleteRope(state.rope)
        deleteRope(state.handRope)
        if state.prop and DoesEntityExist(state.prop) and NetworkHasControlOfEntity(state.prop) then
            DeleteEntity(state.prop)
        end
    end
    state = nil
end

---Starts the rope method on a wall ATM.
---@param entity integer
function FD.Atm.Rope.Start(entity)
    if state then
        return Bridge.Notify(locale('atm.rope_already'), 'error')
    end

    local ok, message = lib.callback.await(FD.Events.Callback.CheckMethod, false, 'rope')
    if not ok then
        return Bridge.Notify(message or locale('atm.missing_rope'), 'error')
    end

    local done = FD.Actions.Run(locale('atm.attaching_rope'), config.atm.methodTime.rope)
    if done == nil then
        return
    end
    if not done or not DoesEntityExist(entity) then
        return TriggerServerEvent(FD.Events.Server.ReleaseAtmMethod)
    end

    TriggerServerEvent(FD.Events.Server.ConsumeAtmItem, 'rope')
    local origin = GetEntityCoords(entity)
    state = {
        stage = 'hand',
        wallAtm = entity,
        model = GetEntityModel(entity),
        origin = origin,
        pulls = 0,
        pullReady = true,
        lastPullAnchor = origin,
        nextSpark = 0,
        nextWatchdog = 0,
    }
    FD.Atm.used[entity] = true

    giveTowHook()
    if towHook and DoesEntityExist(towHook) then
        state.handRope = tieRope(entity, topOf(entity), towHook, GetEntityCoords(towHook), rope.ropeLength)
    end
    Bridge.Notify(locale('atm.rope_attached'), 'success')
end

---Loot the ripped ATM (every crew member takes a share).
---@param entity integer
function FD.Atm.Rope.Loot(entity)
    local netId = FD.Atm.NetIdOf(entity)
    if not FD.Atm.IsActive() or not netId or netId ~= FD.Atm.crewRopeNetId then
        return Bridge.Notify(locale('atm.not_yours'), 'error')
    end
    if not FD.Atm.crewRopeLootable then
        return Bridge.Notify(locale('atm.tow_further'), 'error')
    end
    if not FD.Atm.IsNear(entity, config.atm.lootDistance) then
        return Bridge.Notify(locale('atm.too_far'), 'error')
    end

    TaskTurnPedToFaceEntity(cache.ped, entity, 800)
    Wait(800)
    if FD.Actions.Run(locale('atm.opening_towed'), config.atm.towedLootTime, LOOT_ANIM) then
        TriggerServerEvent(FD.Events.Server.RopeLoot, netId)
    end
end

-- Events ------------------------------------------------------------------------------

RegisterNetEvent(FD.Events.Client.CrewRopeAtm, function(netId)
    FD.Atm.crewRopeNetId = tonumber(netId)
    FD.Atm.crewRopeLootable = false
end)

RegisterNetEvent(FD.Events.Client.CrewRopeLootable, function(netId)
    if FD.Atm.crewRopeNetId == tonumber(netId) then
        FD.Atm.crewRopeLootable = true
    end
end)

RegisterNetEvent(FD.Events.Client.RopeAllLooted, function(netId)
    if FD.Atm.crewRopeNetId == tonumber(netId) then
        Bridge.Notify(locale('atm.all_looted'), 'success')
    end
end)

-- Another crew member is towing: mirror the rope so everyone sees what drags the ATM.
RegisterNetEvent(FD.Events.Client.CrewRopeTow, function(vehicleNetId, atmNetId)
    deleteRope(crewRope)
    crewRope = nil
    if not vehicleNetId or not atmNetId then
        return
    end

    local deadline = GetGameTimer() + 3000
    while
        not (NetworkDoesNetworkIdExist(vehicleNetId) and NetworkDoesNetworkIdExist(atmNetId))
        and GetGameTimer() < deadline
    do
        Wait(100)
    end
    if not NetworkDoesNetworkIdExist(vehicleNetId) or not NetworkDoesNetworkIdExist(atmNetId) then
        return
    end

    local vehicle, atm = NetworkGetEntityFromNetworkId(vehicleNetId), NetworkGetEntityFromNetworkId(atmNetId)
    crewRope = tieRope(atm, topOf(atm), vehicle, rearOf(vehicle), rope.towRopeLength)
end)

RegisterNetEvent(FD.Events.Client.LootTowedAtm, function(data)
    FD.Atm.Rope.Loot(type(data) == 'table' and data.entity or data)
end)

CreateThread(function()
    while true do
        local rs = state
        local tick = rs and FD.Atm.IsActive() and TICKS[rs.stage]
        if tick then
            Wait(0)
            tick(rs)
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
