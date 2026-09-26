--[[
    FD-robberies by FIVE DEV — client configuration.
    Open file: safe to edit. Downloaded by every player — never put secrets here.
]]

return {
    openCommand = 'robberies',
    openKey = 'F6',
    briefingKey = 'B',

    targetResource = 'qb-target',

    hubNpc = {
        enabled = true,
        model = 'g_m_m_armboss_01',
        coords = vec4(1275.14, -1710.63, 53.77, 115.0),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        targetDistance = 2.5,
        invincible = true,
        frozen = true,
        blockEvents = true,
    },

    clothing = {
        enabled = true,
        openEvent = 'qb-clothing:client:openMenu', -- event that opens your clothing menu
        outfits = {
            male = {
                { component = 1, drawable = 35, texture = 0 },
                { component = 3, drawable = 17, texture = 0 },
                { component = 4, drawable = 31, texture = 0 },
                { component = 6, drawable = 25, texture = 0 },
                { component = 8, drawable = 15, texture = 0 },
                { component = 11, drawable = 178, texture = 0 },
            },
            female = {
                { component = 1, drawable = 35, texture = 0 },
                { component = 3, drawable = 18, texture = 0 },
                { component = 4, drawable = 30, texture = 0 },
                { component = 6, drawable = 25, texture = 0 },
                { component = 8, drawable = 14, texture = 0 },
                { component = 11, drawable = 180, texture = 0 },
            },
        },
    },

    nearbyPlayersRadius = 12.0,

    -- generic "location" robberies: target zone at the robbery coords
    location = {
        zoneRadius = 1.8,
        targetDistance = 2.5,
        actionTime = 30000,
    },

    store = {
        clerkModel = 'mp_m_shopkeep_01',
        aimMilliseconds = 1400, -- how long you must aim at the clerk before he surrenders
        aimDistance = 12.0,
        registerTime = 12000,
        shelfTime = 8500,
        safeTime = 15000,
        registerZoneRadius = 0.65,
        shelfZoneRadius = 0.7,
        safeZoneRadius = 0.8,
        registerTargetDistance = 1.7,
        lootTargetDistance = 1.8,
    },

    atm = {
        models = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' },
        targetDistance = 3.2,
        closeTargetRadius = 1.15, -- extra zone so ALT works when standing right against the ATM
        closeZoneScanRadius = 35.0,
        lootDistance = 3.0,
        methodTime = { drill = 30000, explosive = 12000, rope = 5000 },
        blastLootTime = 9000,
        towedLootTime = 12000,
        explosionCountdown = 5,
        rope = {
            vehicleAttachDistance = 7.0,
            pullCount = 2,
            pullSpeed = 6.5,
            pullDistance = 3.5,
            pullResetSpeed = 1.15,
            pullResetMs = 700,
            lootDistanceFromOrigin = 35.0,
            ropeLength = 9.0,
            hookModel = 'prop_rope_hook_01',
        },
    },
}
