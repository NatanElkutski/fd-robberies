--[[
    ATM breach (client) — rope + vehicle method.

    GTA can't tie ropes to map objects and map ATMs aren't networked, so the moment the rope is
    tied, the wall ATM is swapped for an identical networked ATM prop (frozen in place, same
    model/position/rotation) and only that exact wall ATM is hidden. Every rope attaches to the
    prop, and the whole crew sees and loots the same ATM.

    Stages:
      hand      rope tied to the ATM, hook in the player's hand → [E] at a vehicle's trunk
      anchored  rope ATM ↔ vehicle; the driver does N hard pulls (stop between pulls)
      towing    the ATM breaks off (unfrozen, real physics): falls, drags, bounces, sparks.
                A watchdog puts it back behind the car if physics lose it. Once the vehicle
                stands still far enough from the wall, the crew can loot it (rope stays on).
      loose     the vehicle was lost before the loot distance → re-hook to another vehicle
    The ATM prop and the rope are removed only after the crew has taken the money.

    Prompts use ox_lib text UI (NUI) — GTA's native text renderer has no Hebrew glyphs.
]]

local config = require('config.client')

local rope = config.atm.rope
local ROPE_TYPE <const> = 4
local VEHICLE_REAR_OFFSET <const> = vec3(0.0, -2.2, 0.3)
local HOOK_PROMPT_DISTANCE <const> = 2.6
local STOP_SPEED <const> = 0.45
local SPARK_INTERVAL_MS <const> = 120
local WATCHDOG_INTERVAL_MS <const> = 400
local RIGHT_HAND_BONE <const> = 57005
local LOOT_ANIM <const> = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'grab', flag = 1 }
local CONTROL_E <const> = 38

---@class RopeState
---@field stage 'hand'|'anchored'|'towing'|'loose'
---@field wallAtm integer            the hidden map ATM
---@field model integer
---@field origin vector3
---@field prop integer               networked ATM prop (frozen on the wall until ripped)
---@field netId integer
---@field vehicle? integer
---@field rope? integer              rope prop ↔ vehicle
---@field handRope? integer          rope prop ↔ hook in hand
---@field pulls integer
---@field pullReady boolean
---@field stopSince? integer
---@field lootable boolean
---@field nextSpark integer
---@field nextWatchdog integer

---@type RopeState|nil
local state = nil
local towHook = nil
---@type integer|nil rope mirrored from another crew member's tow
local crewRope = nil
---@type string|nil text currently shown in the text UI
local promptText = nil

-- Helpers ----------------------------------------------------------------------

---@param text? string nil hides the prompt
local function setPrompt(text)
    if text == promptText then
        return
    end
    promptText = text
    if text then
        lib.showTextUI(text, { position = 'right-center', icon = 'link' })
    else
        lib.hideTextUI()
    end
end

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

---Rope tied between two script entities at the given world positions.
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

---Closest vehicle whose trunk the player is standing at (on foot), or nil.
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

---Marker + Hebrew prompt at a vehicle's trunk; returns the vehicle when E is pressed.
---@return integer|nil
local function promptHookVehicle()
    local vehicle, rear = vehicleAtRear()
    if not vehicle or not rear then
        setPrompt(nil)
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
    setPrompt(locale('atm.attach_hook_prompt'))
    if IsControlJustPressed(0, CONTROL_E) then
        setPrompt(nil)
        return vehicle
    end
end

---Mirrors the rope (ATM ↔ vehicle) for the rest of the crew; nil clears it.
---@param vehicle? integer
local function syncCrewRope(vehicle)
    TriggerServerEvent(FD.Events.Server.RopeTowSync, vehicle and FD.Atm.NetIdOf(vehicle) or nil)
end

---Swaps the wall ATM for an identical networked prop, frozen in place.
---@param wallAtm integer
---@return integer|nil prop
---@return integer|nil netId
local function replaceWallAtm(wallAtm)
    local model = GetEntityModel(wallAtm)
    local pos = GetEntityCoords(wallAtm)
    local rot = GetEntityRotation(wallAtm, 2)

    -- hide the wall ATM first so the replacement doesn't collide with it
    FD.Atm.World.Hide(pos, model)

    lib.requestModel(model, 5000)
    local prop = CreateObjectNoOffset(model, pos.x, pos.y, pos.z, true, true, false)
    SetModelAsNoLongerNeeded(model)

    local deadline = GetGameTimer() + 2000
    while DoesEntityExist(prop) and not NetworkGetEntityIsNetworked(prop) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not DoesEntityExist(prop) or not NetworkGetEntityIsNetworked(prop) then
        -- usually a server with strict entity lockdown (client-created entities blocked)
        print(('^1[%s] could not create a networked ATM prop (check sv_entityLockdown)^7'):format(FD.Resource))
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
        FD.Atm.World.Restore(pos, model)
        return
    end

    SetEntityRotation(prop, rot.x, rot.y, rot.z, 2, true)
    SetEntityCoordsNoOffset(prop, pos.x, pos.y, pos.z, false, false, false)
    FreezeEntityPosition(prop, true)

    local netId = NetworkGetNetworkIdFromEntity(prop)
    SetNetworkIdCanMigrate(netId, false) -- the puller keeps simulating its physics
    SetNetworkIdExistsOnAllMachines(netId, true)

    return prop, netId
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
---@param length number
local function hookTo(rs, vehicle, length)
    FD.Atm.RequestControl(vehicle)
    rs.vehicle = vehicle
    rs.stopSince = nil
    deleteRope(rs.rope)
    rs.rope = tieRope(rs.prop, topOf(rs.prop), vehicle, rearOf(vehicle), length)
    syncCrewRope(vehicle)
end

---@param rs RopeState
---@param vehicle integer
local function anchorToVehicle(rs, vehicle)
    deleteRope(rs.handRope)
    rs.handRope = nil
    removeTowHook()
    hookTo(rs, vehicle, rope.ropeLength)
    rs.stage = 'anchored'
    Bridge.Notify(locale('atm.hook_attached', rope.pullCount), 'success')
end

---Breaks the prop off the wall: real physics from here on.
---@param rs RopeState
local function ripFromWall(rs)
    local pos = GetEntityCoords(rs.prop)
    FreezeEntityPosition(rs.prop, false)
    SetEntityDynamic(rs.prop, true)
    SetEntityHasGravity(rs.prop, true)
    SetEntityCollision(rs.prop, true, true)
    ActivatePhysics(rs.prop)

    hookTo(rs, rs.vehicle, rope.towRopeLength)
    rs.stage = 'towing'

    -- tip it over and throw it towards the vehicle
    local towards = GetEntityCoords(rs.vehicle) - pos
    local length = #towards
    if length > 0.01 then
        towards = towards / length
    end
    ApplyForceToEntityCenterOfMass(
        rs.prop,
        1,
        towards.x * rope.ripImpulse,
        towards.y * rope.ripImpulse,
        2.5,
        false,
        false,
        true,
        false
    )
    Bridge.Notify(locale('atm.ripped'), 'success')
end

---@param rs RopeState
---@return boolean
local function farEnough(rs)
    return #(GetEntityCoords(rs.prop) - rs.origin) >= rope.lootDistanceFromOrigin
end

---@param rs RopeState
local function makeLootable(rs)
    if rs.lootable then
        return
    end
    rs.lootable = true
    FD.Atm.crewRopeLootable = true
    TriggerServerEvent(FD.Events.Server.RopeLootable, rs.netId)
    Bridge.Notify(locale('atm.dropped'), 'success')
end

---The vehicle is gone: lootable if far enough, otherwise re-hookable to another vehicle.
---@param rs RopeState
local function loseVehicle(rs)
    deleteRope(rs.rope)
    rs.rope = nil
    rs.vehicle = nil
    syncCrewRope(nil)
    if farEnough(rs) then
        rs.stage = 'loose'
        return makeLootable(rs)
    end
    rs.stage = 'loose'
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
        syncCrewRope(nil)
        return
    end

    -- The frozen ATM anchors the rope: a pull counts when the vehicle hits the end of the rope
    -- at speed. Reversing to give the rope slack arms the next pull.
    local speed = GetEntitySpeed(rs.vehicle)
    local stretch = #(rearOf(rs.vehicle) - topOf(rs.prop))

    if rs.pullReady and speed > rope.pullSpeed and stretch >= rope.ropeLength - 1.0 then
        rs.pulls += 1
        rs.pullReady = false
        local finalPull = rs.pulls >= rope.pullCount
        pullEffects(GetEntityCoords(rs.prop), finalPull)

        if finalPull then
            Bridge.Notify(locale('atm.pull_final', rs.pulls, rope.pullCount), 'success')
            ripFromWall(rs)
        else
            Bridge.Notify(locale('atm.pull_ok', rs.pulls, rope.pullCount), 'primary')
        end
        return
    end

    if not rs.pullReady and stretch <= rope.ropeLength - rope.pullSlack then
        rs.pullReady = true
        Bridge.Notify(locale('atm.pull_ready', rs.pulls, rope.pullCount), 'primary')
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
        local hasGround, z = GetGroundZFor_3dCoord(behind.x, behind.y, behind.z + 3.0, false)
        SetEntityCoordsNoOffset(rs.prop, behind.x, behind.y, (hasGround and z or behind.z) + 0.6, false, false, false)
        local velocity = GetEntityVelocity(rs.vehicle)
        SetEntityVelocity(rs.prop, velocity.x, velocity.y, velocity.z)
        ropeGone = true
    end

    if ropeGone then
        hookTo(rs, rs.vehicle, rope.towRopeLength)
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

    if rs.lootable or not farEnough(rs) then
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
    if rs.lootable or not DoesEntityExist(rs.prop) or not FD.Atm.IsNear(rs.prop, rope.looseRehookDistance) then
        setPrompt(nil)
        return
    end
    local vehicle = promptHookVehicle()
    if vehicle then
        hookTo(rs, vehicle, rope.towRopeLength)
        rs.stage = 'towing'
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

---Removes ropes, the hook and (if owned) the ATM prop.
function FD.Atm.Rope.Cleanup()
    setPrompt(nil)
    removeTowHook()
    deleteRope(crewRope)
    crewRope = nil
    if state then
        deleteRope(state.rope)
        deleteRope(state.handRope)
        if DoesEntityExist(state.prop) and NetworkHasControlOfEntity(state.prop) then
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

    local origin = GetEntityCoords(entity)
    local model = GetEntityModel(entity)
    local prop, netId = replaceWallAtm(entity)
    if not prop or not netId then
        TriggerServerEvent(FD.Events.Server.ReleaseAtmMethod)
        return Bridge.Notify(locale('atm.rip_failed'), 'error')
    end

    TriggerServerEvent(FD.Events.Server.ConsumeAtmItem, 'rope')
    TriggerServerEvent(FD.Events.Server.RegisterRopeAtm, netId, origin, model)

    state = {
        stage = 'hand',
        wallAtm = entity,
        model = model,
        origin = origin,
        prop = prop,
        netId = netId,
        pulls = 0,
        pullReady = true,
        lootable = false,
        nextSpark = 0,
        nextWatchdog = 0,
    }
    FD.Atm.used[entity] = true
    FD.Atm.used[prop] = true
    FD.Atm.crewRopeNetId = netId

    giveTowHook()
    if towHook and DoesEntityExist(towHook) then
        state.handRope = tieRope(prop, topOf(prop), towHook, GetEntityCoords(towHook), rope.ropeLength)
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

-- Everyone took their share: the rope and the ATM are removed (the server deletes the prop).
RegisterNetEvent(FD.Events.Client.RopeAllLooted, function(netId)
    if FD.Atm.crewRopeNetId ~= tonumber(netId) then
        return
    end
    if state and FD.Atm.LoadPtfx('core') and DoesEntityExist(state.prop) then
        FD.Atm.Burst('ent_dst_concrete_large', GetEntityCoords(state.prop), 0.8)
    end
    FD.Atm.Rope.Cleanup()
    FD.Atm.crewRopeLootable = false
    Bridge.Notify(locale('atm.all_looted'), 'success')
end)

-- Another crew member hooked the ATM to a vehicle: mirror the rope so everyone sees it.
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
            if promptText then
                setPrompt(nil)
            end
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == FD.Resource then
        FD.Atm.Rope.Cleanup()
    end
end)
