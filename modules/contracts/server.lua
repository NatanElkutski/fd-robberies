--[[
    Contracts (server): starting a robbery, the active-contract state, cooldowns,
    completion routing per robbery kind, closing/cancelling and expiry.
]]

local sharedConfig = require('config.shared')
local config = require('config.server')

local EXPIRY_CHECK_MS <const> = 30000

---@type table<string, ActiveContract>
local active = {}
---@type table<string, integer> robbery id -> os.time() when available again
local cooldowns = {}
---@type table<string, fun(src: integer, id: string, method: any, contract: ActiveContract)>
local completeHandlers = {}
---@type fun(id: string, contract: ActiveContract)[]
local closeHandlers = {}

FD.Contracts = {}

---@param id string
---@return ActiveContract|nil
function FD.Contracts.Get(id)
    return active[id]
end

---@param src integer
---@return string|nil robbery id
function FD.Contracts.FindByMember(src)
    for id, contract in pairs(active) do
        if contract.members[src] then
            return id
        end
    end
end

---@param id string
---@param src integer
---@return boolean
function FD.Contracts.IsMember(id, src)
    local contract = active[id]
    return contract ~= nil and contract.members[src] == true
end

---Per-robbery availability for the hub.
function FD.Contracts.States()
    local now = os.time()
    local states = {}
    for id, robbery in pairs(sharedConfig.robberies) do
        states[id] = {
            active = active[id] ~= nil,
            cooldown = math.max(0, (cooldowns[id] or 0) - now),
            requiredLevel = robbery.level,
        }
    end
    return states
end

---Random dirty-money amount from the robbery's reward range.
---@param id string
---@return integer
function FD.Contracts.RollReward(id)
    local reward = config.robberies[id].reward
    return math.random(reward.min, reward.max)
end

---Lets a robbery kind module handle FD.Events.Server.Complete for its robberies.
---@param kind string
---@param handler fun(src: integer, id: string, method: any, contract: ActiveContract)
function FD.Contracts.OnComplete(kind, handler)
    completeHandlers[kind] = handler
end

---Lets a module clean up world state (spawned props, hidden map objects) whenever a contract ends.
---@param handler fun(id: string, contract: ActiveContract)
function FD.Contracts.OnClose(handler)
    closeHandlers[#closeHandlers + 1] = handler
end

---@param id string
---@param contract ActiveContract
local function runCloseHandlers(id, contract)
    for _, handler in ipairs(closeHandlers) do
        local ok, err = pcall(handler, id, contract)
        if not ok then
            print(('^1[%s] contract close handler failed: %s^7'):format(FD.Resource, err))
        end
    end
end

---@param id string
---@param contract ActiveContract
---@param success boolean
local function notifyEnded(id, contract, success)
    for member in pairs(contract.members) do
        TriggerClientEvent(FD.Events.Client.Ended, member, id, success)
    end
end

---@param id string
---@param notifyKey? string
local function expire(id, notifyKey)
    local contract = active[id]
    active[id] = nil
    runCloseHandlers(id, contract)
    notifyEnded(id, contract, false)
    if notifyKey then
        for member in pairs(contract.members) do
            Bridge.Notify(member, locale(notifyKey), 'error')
        end
    end
end

---Closes the contract (leader only), starts the cooldown and grants XP on success.
---@param src integer
---@param id string
---@param success boolean
local function close(src, id, success)
    local contract = active[id]
    if not contract or not contract.members[src] or not sharedConfig.robberies[id] then
        return
    end

    if src ~= contract.owner then
        return Bridge.Notify(src, locale('contract.only_leader_close'), 'error')
    end

    active[id] = nil
    cooldowns[id] = os.time() + config.robberies[id].cooldown
    runCloseHandlers(id, contract)

    local xp = config.robberies[id].xp
    for member in pairs(contract.members) do
        local identifier = Bridge.GetIdentifier(member)
        if success and identifier then
            FD.Progress.AddCompletion(identifier, xp)
            Bridge.Notify(member, locale('contract.closed_xp', xp), 'success')
        end
        TriggerClientEvent(FD.Events.Client.Ended, member, id, success)
    end
end

---@param id string
---@param contract ActiveContract
---@return boolean
local function isSuccessful(id, contract)
    return (id == 'store' and next(contract.actions) ~= nil)
        or (id == 'atm' and contract.atmCompleted == true)
        or contract.objectiveDone == true
end

---@param src integer
---@param id string
---@return string|nil errorKey locale key of the first failed check
---@return any arg1 format argument for the locale string
---@return any arg2 format argument for the locale string
local function checkCanStart(src, id)
    local robbery = sharedConfig.robberies[id]
    local leader, crew = FD.Crew.Get(src)
    if leader ~= src then
        return 'contract.only_leader_start'
    end

    local progress = FD.Progress.Get(Bridge.GetIdentifier(src) --[[@as string]])
    if FD.Contracts.FindByMember(src) then
        return 'contract.crew_has_active'
    end
    if progress.level < robbery.level then
        return 'contract.locked', robbery.level
    end
    if active[id] then
        return 'contract.in_progress'
    end
    if (cooldowns[id] or 0) > os.time() then
        return 'contract.on_cooldown'
    end
    if Bridge.CountOnDuty(config.policeJob) < robbery.minPolice then
        return 'contract.not_enough_police'
    end

    local count = FD.Crew.Count(crew)
    local minimum = robbery.crew.min or 1
    if count < minimum then
        return 'contract.crew_too_small', minimum, count
    end
    if robbery.crew.max and count > robbery.crew.max then
        return 'contract.crew_too_big', robbery.crew.max, count
    end

    if not config.allowDifferentRobberiesAtSameTime and next(active) then
        return 'contract.other_running'
    end
end

RegisterNetEvent(FD.Events.Server.Start, function(id)
    local src = source
    local robbery = sharedConfig.robberies[id]
    if not Bridge.GetPlayer(src) or not robbery then
        return
    end

    local errorKey, arg1, arg2 = checkCanStart(src, id)
    if errorKey then
        return Bridge.Notify(src, locale(errorKey, arg1, arg2), 'error')
    end

    local _, crew = FD.Crew.Get(src)
    local members = {}
    for member in pairs(crew.members) do
        members[member] = true
    end

    local now = os.time()
    active[id] = {
        owner = src,
        members = members,
        started = now,
        expires = now + robbery.duration,
        actions = {},
        safeCodes = {},
        ropeATM = nil,
        ropeLooted = {},
        atmCompleted = false,
        atmInProgress = nil,
        atmMethod = nil,
        explosiveReady = false,
        objectiveDone = false,
    }

    for member in pairs(members) do
        TriggerClientEvent(FD.Events.Client.Started, member, id, member, robbery.duration)
    end
end)

RegisterNetEvent(FD.Events.Server.Complete, function(id, method)
    local src = source
    local robbery = sharedConfig.robberies[id]
    local contract = active[id]
    if not robbery or not contract or not contract.members[src] or contract.expires < os.time() then
        return
    end
    if not Bridge.GetPlayer(src) then
        return
    end

    local handler = completeHandlers[robbery.kind]
    if handler then
        handler(src, id, method, contract)
    end
end)

RegisterNetEvent(FD.Events.Server.ExitMission, function()
    local src = source
    local id = FD.Contracts.FindByMember(src)
    if not id then
        return Bridge.Notify(src, locale('contract.no_active'), 'error')
    end
    close(src, id, isSuccessful(id, active[id]))
end)

RegisterNetEvent(FD.Events.Server.Cancel, function(id)
    local src = source
    local contract = active[id]
    if contract and contract.members[src] then
        expire(id)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, contract in pairs(active) do
        if contract.members[src] then
            contract.members[src] = nil
            if contract.owner == src then
                expire(id, 'contract.leader_left')
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(EXPIRY_CHECK_MS)
        local now = os.time()
        for id, contract in pairs(active) do
            if contract.expires < now then
                cooldowns[id] = now + config.robberies[id].cooldown
                expire(id, 'contract.timed_out')
            end
        end
    end
end)
