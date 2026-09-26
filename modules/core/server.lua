--[[
    Core (server): startup banner and database schema.
]]

local TABLE = 'fd_robbery_progress'

local function printBanner()
    local version = GetResourceMetadata(FD.Resource, 'version', 0) or '?'
    print('^5======================================================^7')
    print(
        '^5  ███████╗██╗██╗   ██╗███████╗    ██████╗ ███████╗██╗   ██╗^7'
    )
    print(
        '^5  ██╔════╝██║██║   ██║██╔════╝    ██╔══██╗██╔════╝██║   ██║^7'
    )
    print(
        '^5  █████╗  ██║██║   ██║█████╗      ██║  ██║█████╗  ██║   ██║^7'
    )
    print(
        '^5  ██╔══╝  ██║╚██╗ ██╔╝██╔══╝      ██║  ██║██╔══╝  ╚██╗ ██╔╝^7'
    )
    print(
        '^5  ██║     ██║ ╚████╔╝ ███████╗    ██████╔╝███████╗ ╚████╔╝ ^7'
    )
    print(
        '^5  ╚═╝     ╚═╝  ╚═══╝  ╚══════╝    ╚═════╝ ╚══════╝  ╚═══╝  ^7'
    )
    print(('^2  %s v%s loaded successfully - Exclusive FIVE DEV resource^7'):format(FD.Resource, version))
    print('^5======================================================^7')
end

---@param column string
---@return boolean
local function columnExists(column)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { TABLE, column }
    )
    return (count or 0) > 0
end

local function migrate()
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `citizenid` VARCHAR(64) NOT NULL,
            `xp` INT NOT NULL DEFAULT 0,
            `completed` INT NOT NULL DEFAULT 0,
            `criminal_name` VARCHAR(24) NULL,
            `criminal_avatar` VARCHAR(32) NOT NULL DEFAULT 'face01',
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]):format(TABLE))

    -- columns added in earlier versions; older installs may miss them
    if not columnExists('criminal_name') then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `criminal_name` VARCHAR(24) NULL'):format(TABLE))
    end
    if not columnExists('criminal_avatar') then
        MySQL.query.await(
            ("ALTER TABLE `%s` ADD COLUMN `criminal_avatar` VARCHAR(32) NOT NULL DEFAULT 'face01'"):format(TABLE)
        )
    end
end

CreateThread(function()
    Wait(0)
    printBanner()
end)

MySQL.ready(migrate)
