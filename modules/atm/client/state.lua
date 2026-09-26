--[[
    ATM breach (client) — module-internal state and helpers shared by the ATM role files
    (rope, drill, explosive, menu). Other modules must not touch FD.Atm.
]]

local ATM <const> = 'atm'

FD.Atm = {
    ---@type table<integer, true> ATM entities already used on this contract
    used = {},
    ---@type integer|nil ATM entity waiting to be looted after an explosion
    blasted = nil,
    ---@type integer|nil network id of the crew's ripped ATM
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
    NetworkRequestControlOfEntity(entity)
    local deadline = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
end

---@param entity integer
---@param maxDistance number
---@return boolean
function FD.Atm.IsNear(entity, maxDistance)
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(entity)) <= maxDistance
end
