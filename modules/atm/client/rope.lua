--[[
    ATM breach (client) — rope + vehicle method.

    GTA can't tie ropes to map objects and map ATMs aren't networked, so the moment the rope is
    tied, the wall ATM is swapped for an identical networked ATM prop (frozen in place, same
    model/position/rotation) and only that exact wall ATM is hidden. Every rope attaches to the
    prop, and the whole crew sees and loots the same ATM.

    Stages:
      hand      rope tied to the ATM, hook in the player's hand → [E] at a vehicle's trunk
      anchored  rope ATM ↔ vehicle; the rope goes taut at speed = one pull; reverse for slack
      towing    the ATM breaks off: heavy (mass, ground friction, speed cap), a steel body gives
                thin wall ATMs depth, the towing car loses power and top speed. A watchdog puts it
                back behind the car if physics lose it. When the car stands still far enough from
                the wall the crew can loot it (the rope stays on).
      loose     the vehicle was lost before the loot distance → re-hook to another vehicle
    The ATM, its body and the rope are removed only after the crew has taken the money.

    Ropes are flexible (not rigid) and their length follows the distance between their two ends
    (a little sag), capped at the max length — so they look stretched instead of piling up and
    sinking into the ground, and they pull once the cap is reached.

    The [E] prompt floats above the vehicle through the NUI (FD.Nui.WorldPrompt): GTA's native
    text renderer has no Hebrew glyphs.
]]

local config = require('config.client')

local rope = config.atm.rope
local PROMPT_HEIGHT <const> = 0.9
local HOOK_PROMPT_DISTANCE <const> = 2.6
local STOP_SPEED <const> = 0.45
local SPARK_INTERVAL_MS <const> = 120
local WATCHDOG_INTERVAL_MS <const> = 400
local MIN_ROPE_LENGTH <const> = 0.5
local ROPE_REFIT_DELTA <const> = 0.1
local RIGHT_HAND_BONE <const> = 57005
local LOOT_ANIM <const> = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'grab', flag = 1 }
local MOUNT_ANIM <const> = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 }
local CONTROL_E <const> = 38
local UNCAPPED_SPEED <const> = 1000.0

---@class RopeState
---@field stage 'hand'|'anchored'|'towing'|'loose'
---@field wallAtm integer            the hidden map ATM
---@field model integer
---@field origin vector3
---@field frontSign integer          +1 when the ATM's face points along its local +Y, else -1
---@field prop integer               networked ATM prop (frozen on the wall until ripped)
---@field netId integer
---@field body? integer              steel body attached behind thin ATM panels after the rip
---@field bodyPending? boolean       body waits until the ATM is clear of the wall
---@field vehicle? integer
---@field rope? integer              rope prop ↔ vehicle
---@field ropeMax number             max length of `rope`
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
---@type { rope: integer, vehicle: integer, atm: integer, max: number }|nil rope mirrored from another crew member
local crewTow = nil
---@type integer|nil vehicle currently dragging the ripped ATM (local or crew) — gets the load
local loadedVehicle = nil
---@type integer|nil vehicle whose max speed this client capped
local cappedVehicle = nil

-- Ropes ---------------------------------------------------------------------------

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

---How much extra rope can hang between two points before the sag dips below the ground.
---GTA ropes don't collide with the world, so the slack is limited instead: a rope of span d with
---extra length s sags about sqrt(3·d·s/8), i.e. s = 8·h²/(3·d) for an allowed sag depth h
---(the lower end's height above the ground under the middle of the rope).
---@param posA vector3
---@param posB vector3
---@param span number
---@return number slack
local function allowedSlack(posA, posB, span)
    if span < 0.5 then
        return rope.ropeSlack
    end
    local mid = (posA + posB) / 2
    local found, groundZ = GetGroundZFor_3dCoord(mid.x, mid.y, mid.z + 1.0, false)
    if not found then
        return rope.ropeSlack
    end
    local depth = math.min(posA.z, posB.z) - groundZ - rope.groundClearance
    if depth <= 0.0 then
        return 0.0
    end
    return math.min(rope.ropeSlack, 8.0 * depth * depth / (3.0 * span))
end

---Rope length for two ends: the span plus a natural hang that never reaches the ground,
---capped at the max length (at the cap the rope is taut and pulls).
---@param posA vector3
---@param posB vector3
---@param maxLength number
---@return number
local function fittedLength(posA, posB, maxLength)
    local span = #(posA - posB)
    return math.min(maxLength, math.max(MIN_ROPE_LENGTH, span + allowedSlack(posA, posB, span)))
end

---Flexible rope between two entities at the given world positions.
---AddRope(x, y, z, rotX, rotY, rotZ, length, ropeType, maxLength, minLength, windingSpeed,
---        p11, p12, rigid, lengthChangeRate, breakWhenShot) — rigid must stay false,
---otherwise the rope is a stiff rod (it stood straight up / stuck into the ground before).
---@return integer rope handle
local function tieRope(entityA, posA, entityB, posB, maxLength)
    loadRopeTextures()
    local length = fittedLength(posA, posB, maxLength)
    local handle = AddRope(
        posA.x,
        posA.y,
        posA.z,
        0.0,
        0.0,
        0.0,
        length,
        rope.ropeType,
        maxLength,
        MIN_ROPE_LENGTH,
        1.0,
        false,
        false,
        false,
        1.0,
        false
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
        maxLength,
        false,
        false,
        nil,
        nil
    )
    RopeForceLength(handle, length)
    return handle
end

---Keeps a rope's hang natural but above the ground as its ends move: slack when close,
---tightening as they move apart, taut and pulling at the max length.
---@param handle? integer
---@param posA vector3
---@param posB vector3
---@param maxLength number
local function fitRope(handle, posA, posB, maxLength)
    if not handle or not DoesRopeExist(handle) then
        return
    end
    local desired = fittedLength(posA, posB, maxLength)
    if math.abs(GetRopeLength(handle) - desired) > ROPE_REFIT_DELTA then
        RopeForceLength(handle, desired)
    end
end

-- Geometry -----------------------------------------------------------------------------

---Tow point at the back of a vehicle, from its real model dimensions (works for any car size).
---@param vehicle integer
---@return vector3 local offset
local function towPointOffset(vehicle)
    local min = GetModelDimensions(GetEntityModel(vehicle))
    return vec3(0.0, min.y + 0.05, min.z + rope.towPointHeight)
end

---@param vehicle integer
---@return vector3 world position of the tow point
local function rearOf(vehicle)
    local offset = towPointOffset(vehicle)
    return GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z)
end

---@param entity integer
---@return vector3
local function topOf(entity)
    return GetEntityCoords(entity) + vec3(0.0, 0.0, 0.45)
end

-- Hook in hand ---------------------------------------------------------------------------

local function removeTowHook()
    if towHook and DoesEntityExist(towHook) then
        DeleteEntity(towHook)
    end
    towHook = nil
end

---Creates the (networked) tow hook prop so the whole crew sees it.
---@return integer|nil
local function spawnHook()
    local model = joaat(rope.hookModel)
    RequestModel(model)
    local deadline = GetGameTimer() + 2500
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not HasModelLoaded(model) then
        return
    end
    local pos = GetEntityCoords(cache.ped)
    local hook = CreateObject(model, pos.x, pos.y, pos.z - 3.0, true, true, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(hook, false, false)
    return hook
end

---Mounts the hook on the vehicle's tow point; it stays there while pulling and towing.
---@param vehicle integer
local function mountHook(vehicle)
    if not towHook or not DoesEntityExist(towHook) then
        towHook = spawnHook()
    end
    if not towHook then
        return
    end
    DetachEntity(towHook, true, false)
    local offset, rotation = towPointOffset(vehicle), rope.hookVehicleRotation
    AttachEntityToEntity(
        towHook,
        vehicle,
        0,
        offset.x,
        offset.y,
        offset.z,
        rotation.x,
        rotation.y,
        rotation.z,
        false,
        false,
        false,
        false,
        2,
        true
    )
end

local function giveTowHook()
    removeTowHook()
    towHook = spawnHook()
    if not towHook then
        return
    end

    local ped = cache.ped
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
end

-- Vehicle prompt ---------------------------------------------------------------------------

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

---Marker + floating Hebrew prompt above the vehicle's trunk; returns the vehicle when E is pressed.
---@return integer|nil
local function promptHookVehicle()
    local vehicle, rear = vehicleAtRear()
    if not vehicle or not rear then
        FD.Nui.WorldPrompt(nil)
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
    FD.Nui.WorldPrompt(locale('atm.attach_hook_prompt'), rear + vec3(0.0, 0.0, PROMPT_HEIGHT), 'E')
    if IsControlJustPressed(0, CONTROL_E) then
        FD.Nui.WorldPrompt(nil)
        return vehicle
    end
end

---Mirrors the rope (ATM ↔ vehicle) for the rest of the crew; nil clears it.
---@param vehicle? integer
---@param towing? boolean the ATM is ripped out (the vehicle carries the load)
local function syncCrewRope(vehicle, towing)
    TriggerServerEvent(FD.Events.Server.RopeTowSync, vehicle and FD.Atm.NetIdOf(vehicle) or nil, towing == true)
end

-- Props ---------------------------------------------------------------------------------

---@param entity integer
---@return boolean networked
local function waitNetworked(entity)
    local deadline = GetGameTimer() + 2000
    while DoesEntityExist(entity) and not NetworkGetEntityIsNetworked(entity) and GetGameTimer() < deadline do
        Wait(0)
    end
    return DoesEntityExist(entity) and NetworkGetEntityIsNetworked(entity)
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

    if not waitNetworked(prop) then
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

---Wall ATM models are only a front panel (the rest is inside the wall). Once ripped out, attach a
---steel body behind the panel so it has real depth. Skipped for models that are already deep.
---@param rs RopeState
local function attachBody(rs)
    local panelMin, panelMax = GetModelDimensions(rs.model)
    local panelDepth = panelMax.y - panelMin.y
    local bodyModel = joaat(rope.bodyModel)
    if panelDepth >= rope.bodyMinPanelDepth or not IsModelInCdimage(bodyModel) then
        return
    end

    lib.requestModel(bodyModel, 3000)
    local pos = GetEntityCoords(rs.prop)
    local body = CreateObject(bodyModel, pos.x, pos.y, pos.z - 5.0, true, true, false)
    SetModelAsNoLongerNeeded(bodyModel)
    if not waitNetworked(body) then
        if DoesEntityExist(body) then
            DeleteEntity(body)
        end
        return
    end
    -- purely visual depth: it must never collide (it would snag on walls, kerbs and the car)
    SetEntityCollision(body, false, false)
    SetEntityNoCollisionEntity(body, rs.prop, false)

    local bodyMin, bodyMax = GetModelDimensions(bodyModel)
    local panelCenter = (panelMin + panelMax) / 2
    local bodyCenter = (bodyMin + bodyMax) / 2
    local bodyDepth = bodyMax.y - bodyMin.y
    -- behind the panel: opposite side of its face, touching its back
    local offsetY = panelCenter.y - rs.frontSign * (panelDepth / 2 + bodyDepth / 2 - 0.02) - bodyCenter.y

    AttachEntityToEntity(
        body,
        rs.prop,
        0,
        panelCenter.x - bodyCenter.x,
        offsetY,
        panelCenter.z - bodyCenter.z,
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

    rs.body = body
    TriggerServerEvent(FD.Events.Server.RegisterAtmBody, NetworkGetNetworkIdFromEntity(body))
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

---Ground friction: a heavy steel box doesn't slide freely — bleed off horizontal speed while it
---touches the ground, so the rope has to haul it (and the car feels the load).
---@param rs RopeState
local function groundDrag(rs)
    if IsEntityInAir(rs.prop) then
        return
    end
    local velocity = GetEntityVelocity(rs.prop)
    local keep = math.max(0.0, 1.0 - rope.groundDrag * GetFrameTime())
    SetEntityVelocity(rs.prop, velocity.x * keep, velocity.y * keep, velocity.z)
end

-- Stage transitions ---------------------------------------------------------------------

---@param rs RopeState
---@param vehicle integer
---@param maxLength number
local function hookTo(rs, vehicle, maxLength)
    FD.Atm.RequestControl(vehicle)
    rs.vehicle = vehicle
    rs.stopSince = nil
    rs.ropeMax = maxLength
    deleteRope(rs.rope)
    rs.rope = tieRope(rs.prop, topOf(rs.prop), vehicle, rearOf(vehicle), maxLength)

    local towing = rs.stage == 'towing' or rs.stage == 'loose'
    loadedVehicle = towing and vehicle or nil
    syncCrewRope(vehicle, towing)
end

---Kneel at the trunk and mount the hook on the vehicle (animation). The rope's end moves from
---the hook in the hand to the hook on the vehicle — the same point — so it stays connected.
---@param rs RopeState
---@param vehicle integer
---@return boolean mounted
local function mountOnVehicle(rs, vehicle)
    local point = rearOf(vehicle)
    TaskTurnPedToFaceCoord(cache.ped, point.x, point.y, point.z, 700)
    Wait(700)
    if not FD.Actions.Run(locale('atm.mounting_hook'), rope.hookAttachTime, MOUNT_ANIM) then
        return false -- cancelled or busy: the player keeps holding the hook
    end
    if not DoesEntityExist(vehicle) or not DoesEntityExist(rs.prop) then
        return false
    end

    mountHook(vehicle)
    deleteRope(rs.handRope)
    rs.handRope = nil
    return true
end

---@param rs RopeState
---@param vehicle integer
local function anchorToVehicle(rs, vehicle)
    if not mountOnVehicle(rs, vehicle) then
        return
    end
    rs.stage = 'anchored'
    hookTo(rs, vehicle, rope.ropeLength)
    Bridge.Notify(locale('atm.hook_attached', rope.pullCount), 'success')
end

---Breaks the prop off the wall: real, heavy physics from here on.
---@param rs RopeState
local function ripFromWall(rs)
    -- step out of the wall along the ATM's face before physics start, so no part of it is
    -- inside the wall geometry (that's what made it snag on the wall)
    local out = GetEntityForwardVector(rs.prop) * rs.frontSign
    local pos = GetEntityCoords(rs.prop) + out * rope.wallClearance
    SetEntityCoordsNoOffset(rs.prop, pos.x, pos.y, pos.z, false, false, false)

    FreezeEntityPosition(rs.prop, false)
    SetEntityDynamic(rs.prop, true)
    SetEntityHasGravity(rs.prop, true)
    SetEntityCollision(rs.prop, true, true)
    SetObjectPhysicsParams(rs.prop, rope.atmMass, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0)
    SetEntityMaxSpeed(rs.prop, rope.atmMaxSpeed)
    ActivatePhysics(rs.prop)
    rs.bodyPending = true -- the steel body is attached once the ATM is clear of the wall

    rs.stage = 'towing'
    hookTo(rs, rs.vehicle, rope.towRopeLength)

    -- throw it away from the wall (mostly) and towards the vehicle, tipping it over
    local towards = GetEntityCoords(rs.vehicle) - pos
    local length = #towards
    if length > 0.01 then
        towards = towards / length
    end
    local push = (out * 0.6 + towards * 0.4) * rope.ripImpulse
    ApplyForceToEntityCenterOfMass(rs.prop, 1, push.x, push.y, 2.5, false, false, true, false)
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
    removeTowHook() -- it was mounted on the lost vehicle; a new one is mounted when re-hooking
    rs.vehicle = nil
    rs.stage = 'loose'
    loadedVehicle = nil
    syncCrewRope(nil)
    if farEnough(rs) then
        return makeLootable(rs)
    end
    Bridge.Notify(locale('atm.vehicle_lost'), 'error')
end

-- Per-frame stage logic ---------------------------------------------------------------------

---@param rs RopeState
local function tickHand(rs)
    if towHook and DoesEntityExist(towHook) then
        fitRope(rs.handRope, topOf(rs.prop), GetEntityCoords(towHook), rope.handRopeLength)
    end
    local vehicle = promptHookVehicle()
    if vehicle then
        anchorToVehicle(rs, vehicle)
    end
end

---The frozen ATM anchors the rope: a pull counts when the vehicle hits the end of the rope at
---speed. Reversing to give the rope slack arms the next pull.
---@param rs RopeState
local function tickAnchored(rs)
    if not rs.vehicle or not DoesEntityExist(rs.vehicle) then
        deleteRope(rs.rope)
        rs.rope, rs.vehicle, rs.stage = nil, nil, 'hand'
        syncCrewRope(nil)
        return
    end

    local anchor, rear = topOf(rs.prop), rearOf(rs.vehicle)
    fitRope(rs.rope, anchor, rear, rope.ropeLength)

    local speed = GetEntitySpeed(rs.vehicle)
    local stretch = #(rear - anchor)

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

    fitRope(rs.rope, topOf(rs.prop), rearOf(rs.vehicle), rs.ropeMax)
    if rs.bodyPending and #(GetEntityCoords(rs.prop) - rs.origin) >= rope.bodyAttachDistance then
        rs.bodyPending = false
        attachBody(rs)
    end
    groundDrag(rs)
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
        FD.Nui.WorldPrompt(nil)
        return
    end
    local vehicle = promptHookVehicle()
    if vehicle and mountOnVehicle(rs, vehicle) then
        rs.stage = 'towing'
        hookTo(rs, vehicle, rope.towRopeLength)
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

---Removes ropes, the hook, the vehicle load and (if owned) the ATM prop and body.
function FD.Atm.Rope.Cleanup()
    FD.Nui.WorldPrompt(nil)
    removeTowHook()
    loadedVehicle = nil
    if crewTow then
        deleteRope(crewTow.rope)
        crewTow = nil
    end
    if state then
        deleteRope(state.rope)
        deleteRope(state.handRope)
        for _, entity in ipairs({ state.body or 0, state.prop }) do
            if entity ~= 0 and DoesEntityExist(entity) and NetworkHasControlOfEntity(entity) then
                DeleteEntity(entity)
            end
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

    -- the hook is in the player's hand while the rope is tied to the ATM, and stays there
    giveTowHook()
    local done = FD.Actions.Run(locale('atm.attaching_rope'), config.atm.methodTime.rope)
    if not done or not DoesEntityExist(entity) then
        removeTowHook()
        if done == false then
            TriggerServerEvent(FD.Events.Server.ReleaseAtmMethod)
        end
        return
    end

    local origin = GetEntityCoords(entity)
    local model = GetEntityModel(entity)
    -- the player stands in front of the ATM: that side is its face
    local pedPos = GetEntityCoords(cache.ped)
    local facing = GetOffsetFromEntityGivenWorldCoords(entity, pedPos.x, pedPos.y, pedPos.z)
    local prop, netId = replaceWallAtm(entity)
    if not prop or not netId then
        removeTowHook()
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
        frontSign = facing.y >= 0.0 and 1 or -1,
        prop = prop,
        netId = netId,
        ropeMax = rope.ropeLength,
        pulls = 0,
        pullReady = true,
        lootable = false,
        nextSpark = 0,
        nextWatchdog = 0,
    }
    FD.Atm.used[entity] = true
    FD.Atm.used[prop] = true
    FD.Atm.crewRopeNetId = netId

    if not towHook or not DoesEntityExist(towHook) then
        giveTowHook()
    end
    if towHook and DoesEntityExist(towHook) then
        state.handRope = tieRope(prop, topOf(prop), towHook, GetEntityCoords(towHook), rope.handRopeLength)
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

-- Everyone took their share: the rope and the ATM are removed (the server deletes the props).
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

-- Another crew member hooked the ATM to a vehicle: mirror the rope so everyone sees it, and give
-- the vehicle its load when this client is the one driving it.
RegisterNetEvent(FD.Events.Client.CrewRopeTow, function(vehicleNetId, atmNetId, towing)
    if crewTow then
        deleteRope(crewTow.rope)
        crewTow = nil
    end
    if not state then
        loadedVehicle = nil
    end
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
    local max = towing and rope.towRopeLength or rope.ropeLength
    crewTow =
        { rope = tieRope(atm, topOf(atm), vehicle, rearOf(vehicle), max), vehicle = vehicle, atm = atm, max = max }
    if towing then
        loadedVehicle = vehicle
    end
end)

RegisterNetEvent(FD.Events.Client.LootTowedAtm, function(data)
    FD.Atm.Rope.Loot(type(data) == 'table' and data.entity or data)
end)

-- Rope stages (per frame while active).
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

-- Mirrored crew rope follows its ends like the local one.
CreateThread(function()
    while true do
        local tow = crewTow
        if tow and DoesEntityExist(tow.vehicle) and DoesEntityExist(tow.atm) then
            fitRope(tow.rope, topOf(tow.atm), rearOf(tow.vehicle), tow.max)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Load on the towing vehicle: less power and a lower top speed while it drags the ATM. Runs on
-- whichever crew client is driving it (the driver's client simulates the vehicle).
CreateThread(function()
    while true do
        local vehicle = loadedVehicle
        local driving = vehicle
            and DoesEntityExist(vehicle)
            and cache.vehicle == vehicle
            and GetPedInVehicleSeat(vehicle, -1) == cache.ped

        if driving then
            SetVehicleCheatPowerIncrease(vehicle, rope.towPowerMultiplier)
            if cappedVehicle ~= vehicle then
                SetEntityMaxSpeed(vehicle, rope.towMaxSpeed)
                cappedVehicle = vehicle
            end
            Wait(0)
        else
            if cappedVehicle then
                if DoesEntityExist(cappedVehicle) then
                    SetEntityMaxSpeed(cappedVehicle, UNCAPPED_SPEED)
                end
                cappedVehicle = nil
            end
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= FD.Resource then
        return
    end
    FD.Atm.Rope.Cleanup()
    if cappedVehicle and DoesEntityExist(cappedVehicle) then
        SetEntityMaxSpeed(cappedVehicle, UNCAPPED_SPEED)
    end
end)
