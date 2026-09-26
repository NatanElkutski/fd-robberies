--[[
    ATM breach (client) — module-internal state and helpers shared by the ATM role files
    (world, rope, drill, explosive, menu). Other modules must not touch FD.Atm.
]]

local ATM <const> = 'atm'

FD.Atm = {
    ---@type table<integer, true> ATM entities already used on this contract
    used = {},
    ---@type integer|nil ATM entity waiting to be looted after an explosion
    blasted = nil,
    ---@type integer|nil network id of the crew's ripped (spawned) ATM prop
    crewRopeNetId = nil,
    crewRopeLootable = false,
}

---@return boolean
function FD.Atm.IsActive()
    return FD.Mission.Is(ATM)
end

---Asks the server to pay out the ATM (drill / explosive_loot).
---@param method string
function FD.Atm.Finish(method)
    local mission = FD.Mission.Current()
    if mission then
        TriggerServerEvent(FD.Events.Server.Complete, mission.id, method)
    end
end

---Requests network control of an entity (up to 1.5 s).
---@param entity integer
function FD.Atm.RequestControl(entity)
    if not NetworkGetEntityIsNetworked(entity) then
        return
    end
    NetworkRequestControlOfEntity(entity)
    local deadline = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
end

---Network id of an entity, or nil for local/map entities (map ATMs are never networked —
---calling NetworkGetNetworkIdFromEntity on them spams "no net object for entity").
---@param entity integer
---@return integer|nil
function FD.Atm.NetIdOf(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) and NetworkGetEntityIsNetworked(entity) then
        return NetworkGetNetworkIdFromEntity(entity)
    end
end

---@param entity integer
---@param maxDistance number
---@return boolean
function FD.Atm.IsNear(entity, maxDistance)
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(entity)) <= maxDistance
end

---@param asset string
---@return boolean loaded
function FD.Atm.LoadPtfx(asset)
    RequestNamedPtfxAsset(asset)
    local deadline = GetGameTimer() + 1500
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasNamedPtfxAssetLoaded(asset)
end

---One-shot particle effect from the core asset (asset must be loaded).
---@param name string
---@param pos vector3
---@param scale number
function FD.Atm.Burst(name, pos, scale)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord(name, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, scale, false, false, false)
end
