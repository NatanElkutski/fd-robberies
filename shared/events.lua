--[[
    Every event and callback name used by this resource. Never type these strings elsewhere.
    The string values are part of the public contract (other resources / anticheat whitelists
    may reference them) — don't rename without a major version bump.
]]

local function server(name)
    return ('%s:server:%s'):format(FD.Resource, name)
end

local function client(name)
    return ('%s:client:%s'):format(FD.Resource, name)
end

FD.Events = {
    -- client -> server net events
    Server = {
        SaveProfile = server('saveCriminalProfile'),
        CrewInvite = server('crewInvite'),
        CrewAccept = server('crewAccept'),
        CrewLeave = server('crewLeave'),
        LobbyMessage = server('lobbyMessage'),
        Start = server('start'),
        Complete = server('complete'),
        ExitMission = server('exitMission'),
        Cancel = server('cancel'),
        BuyItem = server('buyItem'),
        StoreAction = server('storeAction'),
        ReleaseAtmMethod = server('releaseATMMethod'),
        ExplosiveReady = server('explosiveReady'),
        ConsumeAtmItem = server('consumeATMItem'),
        RegisterRopeAtm = server('registerRopeATM'),
        RopeLootable = server('ropeLootable'),
        RopeLoot = server('ropeLoot'),
    },

    -- server -> client net events (and a few local target events)
    Client = {
        Notify = client('notify'),
        CrewRefresh = client('crewRefresh'),
        LobbyMessage = client('lobbyMessage'),
        Started = client('started'),
        Ended = client('ended'),
        OpenAtmMethods = client('openATMMethods'),
        LootBlastedAtm = client('lootBlastedATM'),
        LootTowedAtm = client('lootTowedATM'),
        CrewRopeAtm = client('crewRopeATM'),
        CrewRopeLootable = client('crewRopeLootable'),
        DetachRopeAfterLoot = client('detachRopeAfterLoot'),
        RopeAllLooted = client('ropeAllLooted'),
    },

    -- ox_lib callbacks (client asks, server answers)
    Callback = {
        GetData = server('getData'),
        CheckMethod = server('checkMethod'),
        GetSafeHint = server('getSafeHint'),
    },
}
