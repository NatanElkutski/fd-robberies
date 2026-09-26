--[[
    FD-robberies by FIVE DEV — shared configuration (client + server).
    Open file: safe to edit. Text for every robbery (name, description, briefing)
    lives in locales/*.json under "robbery.<id>".
]]

---@class RobberyCrewSize
---@field min integer
---@field max? integer   nil = no upper limit

---@class RobberyDefinition
---@field kind 'location'|'store'|'atm'
---@field level integer      required criminal level
---@field minPolice integer  on-duty police required to start
---@field duration integer   seconds the crew has to finish
---@field coords userdata    vec3 objective location (location robberies)
---@field radius number
---@field crew RobberyCrewSize

return {
    ---@type table<string, RobberyDefinition>
    robberies = {
        store = {
            kind = 'store',
            level = 1,
            minPolice = 0,
            duration = 10 * 60,
            coords = vec3(24.47, -1345.63, 29.50),
            radius = 30,
            crew = { min = 3, max = 3 },
        },
        atm = {
            kind = 'atm',
            level = 1,
            minPolice = 0,
            duration = 10 * 60,
            coords = vec3(-2072.45, -317.25, 13.32),
            radius = 25,
            crew = { min = 1, max = 2 },
        },
        house = {
            kind = 'location',
            level = 2,
            minPolice = 0,
            duration = 12 * 60,
            coords = vec3(-174.19, 502.55, 137.42),
            radius = 30,
            crew = { min = 2 },
        },
        container = {
            kind = 'location',
            level = 2,
            minPolice = 1,
            duration = 12 * 60,
            coords = vec3(896.83, -2534.37, 28.29),
            radius = 38,
            crew = { min = 2 },
        },
        vehicle = {
            kind = 'location',
            level = 2,
            minPolice = 1,
            duration = 12 * 60,
            coords = vec3(-1267.17, -365.15, 36.91),
            radius = 35,
            crew = { min = 2 },
        },
        fleeca = {
            kind = 'location',
            level = 3,
            minPolice = 2,
            duration = 15 * 60,
            coords = vec3(146.87, -1046.05, 29.37),
            radius = 38,
            crew = { min = 3 },
        },
        jewelry = {
            kind = 'location',
            level = 3,
            minPolice = 2,
            duration = 15 * 60,
            coords = vec3(-629.82, -236.71, 38.05),
            radius = 42,
            crew = { min = 3 },
        },
        warehouse = {
            kind = 'location',
            level = 4,
            minPolice = 2,
            duration = 16 * 60,
            coords = vec3(997.12, -2529.31, 28.30),
            radius = 48,
            crew = { min = 3 },
        },
        armored = {
            kind = 'location',
            level = 4,
            minPolice = 3,
            duration = 16 * 60,
            coords = vec3(1213.36, -3232.71, 5.53),
            radius = 50,
            crew = { min = 3 },
        },
        yacht = {
            kind = 'location',
            level = 5,
            minPolice = 3,
            duration = 18 * 60,
            coords = vec3(-2045.84, -1031.14, 11.98),
            radius = 55,
            crew = { min = 4 },
        },
        humane = {
            kind = 'location',
            level = 5,
            minPolice = 3,
            duration = 18 * 60,
            coords = vec3(3611.75, 3744.30, 28.69),
            radius = 60,
            crew = { min = 4 },
        },
        bobcat = {
            kind = 'location',
            level = 6,
            minPolice = 4,
            duration = 20 * 60,
            coords = vec3(888.15, -2129.75, 30.23),
            radius = 60,
            crew = { min = 4 },
        },
        paleto = {
            kind = 'location',
            level = 7,
            minPolice = 4,
            duration = 20 * 60,
            coords = vec3(-104.74, 6477.95, 31.63),
            radius = 65,
            crew = { min = 4 },
        },
        casino = {
            kind = 'location',
            level = 8,
            minPolice = 5,
            duration = 22 * 60,
            coords = vec3(925.20, 46.32, 81.11),
            radius = 70,
            crew = { min = 5 },
        },
        pacific = {
            kind = 'location',
            level = 10,
            minPolice = 6,
            duration = 25 * 60,
            coords = vec3(255.23, 225.37, 101.88),
            radius = 75,
            crew = { min = 6 },
        },
    },

    -- Convenience stores used by the "store" contract. Adjust coordinates for custom MLOs.
    -- ped = clerk position + heading, registers/shelves = loot points, safe = rear safe.
    stores = {
        {
            label = '24/7 Strawberry',
            ped = vec4(24.47, -1346.62, 29.50, 271.0),
            registers = { vec3(24.47, -1344.99, 29.50), vec3(24.95, -1344.94, 29.50) },
            shelves = { vec3(27.65, -1342.63, 29.50), vec3(29.40, -1345.05, 29.50) },
            safe = vec3(28.20, -1339.23, 29.50),
        },
        {
            label = 'LTD Grove Street',
            ped = vec4(-47.17, -1758.72, 29.42, 50.0),
            registers = { vec3(-47.24, -1757.65, 29.42), vec3(-48.58, -1759.21, 29.42) },
            shelves = { vec3(-52.05, -1754.15, 29.42), vec3(-54.30, -1751.70, 29.42) },
            safe = vec3(-43.43, -1748.30, 29.42),
        },
        {
            label = 'LTD Mirror Park',
            ped = vec4(1164.86, -323.64, 69.21, 100.0),
            registers = { vec3(1165.05, -324.49, 69.21), vec3(1164.69, -322.76, 69.21) },
            shelves = { vec3(1161.45, -319.64, 69.21), vec3(1159.90, -324.30, 69.21) },
            safe = vec3(1159.46, -314.05, 69.21),
        },
        {
            label = '24/7 Innocence',
            ped = vec4(372.66, 326.98, 103.57, 255.0),
            registers = { vec3(373.08, 328.58, 103.57), vec3(372.50, 326.42, 103.57) },
            shelves = { vec3(377.05, 329.20, 103.57), vec3(379.30, 326.50, 103.57) },
            safe = vec3(378.18, 333.40, 103.57),
        },
        {
            label = '24/7 Clinton',
            ped = vec4(2557.20, 380.80, 108.62, 0.0),
            registers = { vec3(2554.87, 380.90, 108.62), vec3(2557.24, 380.80, 108.62) },
            shelves = { vec3(2553.10, 384.25, 108.62), vec3(2550.85, 381.65, 108.62) },
            safe = vec3(2549.24, 384.88, 108.62),
        },
        {
            label = '24/7 Route 68',
            ped = vec4(1165.05, 2710.78, 38.16, 180.0),
            registers = { vec3(1165.94, 2710.79, 38.16), vec3(1164.85, 2710.76, 38.16) },
            shelves = { vec3(1167.95, 2707.15, 38.16), vec3(1162.20, 2707.45, 38.16) },
            safe = vec3(1169.31, 2717.79, 37.16),
        },
        {
            label = '24/7 Sandy',
            ped = vec4(1960.20, 3740.70, 32.34, 300.0),
            registers = { vec3(1959.20, 3741.52, 32.34), vec3(1960.18, 3740.67, 32.34) },
            shelves = { vec3(1963.75, 3744.15, 32.34), vec3(1965.00, 3741.15, 32.34) },
            safe = vec3(1959.30, 3748.90, 32.34),
        },
        {
            label = '24/7 Senora',
            ped = vec4(2676.40, 3280.10, 55.24, 330.0),
            registers = { vec3(2678.09, 3279.33, 55.24), vec3(2676.39, 3280.15, 55.24) },
            shelves = { vec3(2679.20, 3283.70, 55.24), vec3(2682.05, 3281.35, 55.24) },
            safe = vec3(2672.62, 3286.88, 55.24),
        },
        {
            label = '24/7 Grapeseed',
            ped = vec4(1697.50, 4923.20, 42.06, 325.0),
            registers = { vec3(1698.31, 4924.38, 42.06), vec3(1697.40, 4923.25, 42.06) },
            shelves = { vec3(1702.20, 4921.10, 42.06), vec3(1703.20, 4924.50, 42.06) },
            safe = vec3(1707.85, 4920.40, 42.06),
        },
        {
            label = '24/7 Paleto',
            ped = vec4(1728.20, 6416.00, 35.04, 245.0),
            registers = { vec3(1728.86, 6417.25, 35.04), vec3(1727.70, 6415.25, 35.04) },
            shelves = { vec3(1732.25, 6414.10, 35.04), vec3(1734.05, 6417.10, 35.04) },
            safe = vec3(1734.96, 6420.32, 35.04),
        },
        {
            label = 'LTD Little Seoul',
            ped = vec4(-706.10, -914.55, 19.22, 90.0),
            registers = { vec3(-706.08, -915.42, 19.22), vec3(-706.16, -913.50, 19.22) },
            shelves = { vec3(-710.45, -910.65, 19.22), vec3(-712.40, -914.10, 19.22) },
            safe = vec3(-709.74, -904.16, 19.22),
        },
        {
            label = 'LTD Richman Glen',
            ped = vec4(-1819.25, 793.75, 138.08, 130.0),
            registers = { vec3(-1819.70, 792.40, 138.08), vec3(-1818.80, 794.10, 138.08) },
            shelves = { vec3(-1823.50, 796.00, 138.08), vec3(-1825.00, 792.50, 138.08) },
            safe = vec3(-1829.35, 798.78, 138.19),
        },
        {
            label = "Rob's Liquor Vespucci",
            ped = vec4(-1221.70, -908.35, 12.33, 35.0),
            registers = { vec3(-1222.00, -907.10, 12.33) },
            shelves = { vec3(-1224.80, -905.30, 12.33), vec3(-1226.80, -907.30, 12.33) },
            safe = vec3(-1220.85, -916.05, 11.33),
        },
        {
            label = "Rob's Liquor Morningwood",
            ped = vec4(-1486.50, -377.55, 40.16, 135.0),
            registers = { vec3(-1486.65, -378.50, 40.16) },
            shelves = { vec3(-1489.50, -380.80, 40.16), vec3(-1492.10, -378.50, 40.16) },
            safe = vec3(-1478.94, -375.50, 39.16),
        },
        {
            label = "Rob's Liquor Great Ocean",
            ped = vec4(-2966.30, 390.90, 15.04, 85.0),
            registers = { vec3(-2967.00, 390.90, 15.04) },
            shelves = { vec3(-2969.90, 394.00, 15.04), vec3(-2972.10, 391.00, 15.04) },
            safe = vec3(-2959.55, 387.12, 14.04),
        },
        {
            label = "Rob's Liquor Route 68",
            ped = vec4(1166.00, 2710.90, 38.16, 180.0),
            registers = { vec3(1165.90, 2710.80, 38.16) },
            shelves = { vec3(1162.00, 2708.20, 38.16) },
            safe = vec3(1169.20, 2717.80, 37.16),
        },
        {
            label = "Rob's Liquor El Rancho",
            ped = vec4(1134.20, -982.45, 46.42, 275.0),
            registers = { vec3(1134.15, -982.45, 46.42) },
            shelves = { vec3(1131.20, -980.20, 46.42), vec3(1129.30, -983.50, 46.42) },
            safe = vec3(1126.75, -980.10, 45.42),
        },
    },
}
