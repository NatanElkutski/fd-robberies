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
            pullCount = 2, -- hard pulls needed to rip the ATM off the wall
            pullSpeed = 6.5, -- vehicle speed (m/s) when the rope goes taut for a pull to count
            pullSlack = 3.0, -- reverse this many metres of slack to arm the next pull
            lootDistanceFromOrigin = 35.0, -- how far the ATM must be towed before it can be opened
            ropeLength = 9.0, -- rope from the wall ATM to the vehicle while pulling
            towRopeLength = 6.0, -- rope between the vehicle and the ripped ATM while towing
            hookModel = 'prop_rope_hook_01',
            ripImpulse = 6.0, -- how hard the ATM is thrown towards the vehicle when it breaks off
            stopToDropMs = 1500, -- vehicle must stand still this long to unhook the ATM
            sparksMinSpeed = 2.0, -- ATM speed (m/s) above which it throws sparks while dragged
            rescueExtraDistance = 8.0, -- ATM further than rope length + this from the vehicle is pulled back
            looseRehookDistance = 12.0, -- a loose ATM (vehicle lost) can be re-hooked from this range
        },
    },
}
