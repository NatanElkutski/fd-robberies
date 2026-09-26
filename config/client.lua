--[[
    FD-robberies by FIVE DEV — client configuration.
    Open file: safe to edit. Downloaded by every player — never put secrets here.
]]

return {
    openCommand = 'robberies',
    openKey = 'F6',
    briefingKey = 'B',

    -- Mission panel (timer / objective / briefing) position on screen. Keep it clear of your
    -- chat resource (usually top-left). Any CSS length: '24px', '46vh', '3vw'...
    missionHud = { left = '24px', top = '46vh' },

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
            -- Ropes: they collide with the world and their length follows the distance between the two
            -- ends (small slack), capped at the max length — at the cap the rope is taut and pulls.
            ropeType = 4, -- GTA rope style
            ropeSlack = 0.6, -- max extra rope (metres) for a natural hang; tightens as the ends move apart
            groundClearance = 0.08, -- the sag is limited so the rope's lowest point stays this far above the ground
            towPointHeight = 0.55, -- tow hook height above the bottom of the vehicle (metres)
            hookAttachTime = 1800, -- ms to crouch and mount the hook on the vehicle
            hookVehicleRotation = vec3(0.0, 0.0, 180.0), -- hook rotation when mounted on the vehicle
            handRopeLength = 15.0, -- max rope between the ATM and the hook in your hand
            ropeLength = 9.0, -- max rope from the wall ATM to the vehicle while pulling
            towRopeLength = 6.0, -- max rope between the vehicle and the ripped ATM while towing
            hookModel = 'prop_rope_hook_01',

            ripImpulse = 6.0, -- how hard the ATM is thrown towards the vehicle when it breaks off
            stopToDropMs = 1500, -- vehicle must stand still this long before the crew can loot
            sparksMinSpeed = 2.0, -- ATM speed (m/s) above which it throws sparks while dragged
            rescueExtraDistance = 8.0, -- ATM further than rope length + this from the vehicle is pulled back
            looseRehookDistance = 12.0, -- a loose ATM (vehicle lost) can be re-hooked from this range

            -- Weight and feel of the ripped ATM
            atmMass = 350.0, -- kg
            groundDrag = 2.6, -- how quickly friction slows the ATM while it scrapes the ground (per second)
            atmMaxSpeed = 24.0, -- m/s cap for the ATM itself
            bodyModel = 'prop_ld_int_safe_01', -- steel body attached behind thin wall ATMs so they have depth
            bodyMinPanelDepth = 0.45, -- ATM models thinner than this (metres) get the body
            towMaxSpeed = 22.0, -- m/s (~80 km/h) top speed of the towing vehicle
            towPowerMultiplier = 0.6, -- engine power of the towing vehicle while it drags the ATM
        },
    },
}
