--[[
    Crew (server): every player is in a crew (solo by default). Leaders invite,
    players accept, members leave, leaders disband.
]]

---@type table<integer, CrewState> leader source -> crew
local crews = {}
---@type table<integer, integer> member source -> leader source
local memberOf = {}
---@type table<integer, table<integer, true>> invited source -> set of inviter sources
local invites = {}

FD.Crew = {}

---@param src integer
---@return CrewState
local function makeSoloCrew(src)
    crews[src] = { leader = src, members = { [src] = true } }
    memberOf[src] = src
    return crews[src]
end

---Returns the player's crew, creating a solo crew if needed.
---@param src integer
---@return integer leader
---@return CrewState crew
function FD.Crew.Get(src)
    local leader = memberOf[src]
    if leader and crews[leader] then
        return leader, crews[leader]
    end
    return src, makeSoloCrew(src)
end

---Counts online members, pruning anyone who is no longer loaded.
---@param crew CrewState
---@return integer
function FD.Crew.Count(crew)
    local count = 0
    for member in pairs(crew.members) do
        if Bridge.GetPlayer(member) then
            count += 1
        else
            crew.members[member] = nil
            memberOf[member] = nil
        end
    end
    return count
end

---Crew data for the NUI.
---@param src integer
function FD.Crew.Payload(src)
    local leader, crew = FD.Crew.Get(src)

    local members = {}
    for id in pairs(crew.members) do
        members[#members + 1] = { id = id, name = FD.Progress.DisplayName(id), leader = id == leader }
    end

    local pending = {}
    for from in pairs(invites[src] or {}) do
        if Bridge.GetPlayer(from) then
            pending[#pending + 1] = { id = from, name = FD.Progress.DisplayName(from) }
        end
    end

    return { leader = leader, members = members, invites = pending, isLeader = leader == src }
end

---@param crew CrewState
local function refreshMembers(crew)
    for member in pairs(crew.members) do
        TriggerClientEvent(FD.Events.Client.CrewRefresh, member)
    end
end

RegisterNetEvent(FD.Events.Server.CrewInvite, function(target)
    local src = source
    target = tonumber(target)
    if not target or target == src or not Bridge.GetPlayer(target) then
        return Bridge.Notify(src, locale('crew.player_offline'), 'error')
    end

    local leader = FD.Crew.Get(src)
    if leader ~= src then
        return Bridge.Notify(src, locale('crew.only_leader_invite'), 'error')
    end

    if memberOf[target] and memberOf[target] ~= target then
        return Bridge.Notify(src, locale('crew.already_in_crew'), 'error')
    end

    invites[target] = invites[target] or {}
    invites[target][src] = true
    Bridge.Notify(target, locale('crew.invite_received', FD.Progress.DisplayName(src), src), 'primary')
    TriggerClientEvent(FD.Events.Client.CrewRefresh, target)
end)

RegisterNetEvent(FD.Events.Server.CrewAccept, function(from)
    local src = source
    from = tonumber(from)
    if not from or not (invites[src] and invites[src][from]) or not crews[from] then
        return Bridge.Notify(src, locale('crew.invite_expired'), 'error')
    end

    local _, current = FD.Crew.Get(src)
    if next(current.members, next(current.members)) then
        return Bridge.Notify(src, locale('crew.leave_current_first'), 'error')
    end

    crews[src] = nil
    current.members[src] = nil
    crews[from].members[src] = true
    memberOf[src] = from
    invites[src] = {}

    refreshMembers(crews[from])
    Bridge.Notify(src, locale('crew.joined'), 'success')
end)

RegisterNetEvent(FD.Events.Server.CrewLeave, function()
    local src = source
    local leader, crew = FD.Crew.Get(src)
    if FD.Contracts.FindByMember(src) then
        return Bridge.Notify(src, locale('crew.cannot_leave_active'), 'error')
    end

    if leader == src then
        for member in pairs(crew.members) do
            if member ~= src then
                makeSoloCrew(member)
                Bridge.Notify(member, locale('crew.disbanded'), 'error')
                TriggerClientEvent(FD.Events.Client.CrewRefresh, member)
            end
        end
        makeSoloCrew(src)
    else
        crew.members[src] = nil
        makeSoloCrew(src)
        refreshMembers(crew)
    end

    TriggerClientEvent(FD.Events.Client.CrewRefresh, src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local leader = memberOf[src]
    if leader and crews[leader] then
        crews[leader].members[src] = nil
    end
    memberOf[src] = nil
end)
