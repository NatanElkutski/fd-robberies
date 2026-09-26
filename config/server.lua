--[[
    FD-robberies by FIVE DEV — server configuration.
    Open file: safe to edit. Loaded only on the server; players never download it.
]]

return {
    xpPerLevel = 1000,
    maxLevel = 10,

    policeJob = 'police', -- job counted for minPolice (must be on duty)
    allowDifferentRobberiesAtSameTime = true, -- false = only one robbery on the whole server at a time

    -- Rewards are paid as this item. If it isn't defined, the fallback item is tried,
    -- then the framework cash account, so a finished robbery never pays zero.
    dirtyMoneyItem = 'dirtymoney',
    fallbackCashItem = 'CASH',

    -- Per robbery: XP granted when the contract is closed, cooldown in seconds, dirty-money range.
    robberies = {
        store = { xp = 220, cooldown = 20 * 60, reward = { min = 3000, max = 5500 } },
        atm = { xp = 250, cooldown = 25 * 60, reward = { min = 3500, max = 6500 } },
        house = { xp = 400, cooldown = 35 * 60, reward = { min = 6500, max = 10000 } },
        container = { xp = 450, cooldown = 40 * 60, reward = { min = 8000, max = 13000 } },
        vehicle = { xp = 500, cooldown = 45 * 60, reward = { min = 9000, max = 15000 } },
        fleeca = { xp = 650, cooldown = 55 * 60, reward = { min = 14000, max = 22000 } },
        jewelry = { xp = 700, cooldown = 60 * 60, reward = { min = 16000, max = 26000 } },
        warehouse = { xp = 800, cooldown = 70 * 60, reward = { min = 20000, max = 32000 } },
        armored = { xp = 900, cooldown = 75 * 60, reward = { min = 23000, max = 36000 } },
        yacht = { xp = 1000, cooldown = 90 * 60, reward = { min = 30000, max = 45000 } },
        humane = { xp = 1100, cooldown = 100 * 60, reward = { min = 34000, max = 50000 } },
        bobcat = { xp = 1250, cooldown = 110 * 60, reward = { min = 40000, max = 60000 } },
        paleto = { xp = 1450, cooldown = 125 * 60, reward = { min = 50000, max = 75000 } },
        casino = { xp = 1700, cooldown = 145 * 60, reward = { min = 65000, max = 95000 } },
        pacific = { xp = 2200, cooldown = 180 * 60, reward = { min = 90000, max = 140000 } },
    },

    -- Store contract loot per point.
    store = {
        registerReward = { min = 450, max = 900 },
        shelfReward = { min = 250, max = 650 },
        safeReward = { min = 1800, max = 3600 },
    },

    -- Item required (and consumed) for each ATM method. Set a method to false to require nothing.
    atmItems = { drill = 'drill', explosive = 'thermite', rope = 'rope' },

    -- Chat lobby
    chat = {
        maxLength = 120,
        history = 30,
    },

    -- Robbery equipment shop. Labels/descriptions are in locales under "shop.<item name>".
    shop = {
        cashItem = 'cash', -- cash is an inventory item on this server; use 'CASH' if that's your item name
        allowCashItem = true,
        allowBank = true,
        items = {
            { name = 'rope', price = 850, icon = '🪢' },
            { name = 'lockpick', price = 450, icon = '🗝️' },
            { name = 'thermite', price = 2200, icon = '💣' },
            { name = 'drill', price = 1800, icon = '🛠️' },
            { name = 'electronickit', price = 1450, icon = '💻' },
            { name = 'trojan_usb', price = 1250, icon = '💾' },
            { name = 'screwdriverset', price = 700, icon = '🧰' },
            { name = 'security_card_01', price = 3000, icon = '💳' },
        },
    },
}
