fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fd-robberies'
author 'FIVE DEV'
description 'FD Robberies - Exclusive QBCore robbery network by FIVE DEV'
version '4.1.0'

dependencies {
    'qb-core',
    'oxmysql',
    'ox_lib',
}

-- Load order matters: shared → bridge → core modules → feature modules.
-- Gameplay files are escrowed, so they are listed here instead of being require()d.
shared_scripts {
    '@ox_lib/init.lua',
    'shared/init.lua',
    'shared/locale.lua',
    'shared/events.lua',
    'shared/utils.lua',
    'shared/types.lua',
}

client_scripts {
    'bridge/qb/client.lua',
    'bridge/client.lua',

    'modules/core/client.lua',
    'modules/contracts/client.lua',
    'modules/crew/client.lua',
    'modules/chat/client.lua',
    'modules/progress/client.lua',
    'modules/hub/client.lua',
    'modules/shop/client.lua',
    'modules/location/client.lua',
    'modules/store/client.lua',
    'modules/atm/client/state.lua',
    'modules/atm/client/world.lua',
    'modules/atm/client/rope.lua',
    'modules/atm/client/drill.lua',
    'modules/atm/client/explosive.lua',
    'modules/atm/client/menu.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/qb/server.lua',
    'bridge/server.lua',

    'modules/core/server.lua',
    'modules/progress/server.lua',
    'modules/rewards/server.lua',
    'modules/crew/server.lua',
    'modules/chat/server.lua',
    'modules/contracts/server.lua',
    'modules/hub/server.lua',
    'modules/location/server.lua',
    'modules/shop/server.lua',
    'modules/store/server.lua',
    'modules/atm/server.lua',
}

ui_page 'web/build/index.html'

-- Files players download. config/server.lua is intentionally NOT listed.
files {
    'config/shared.lua',
    'config/client.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/**/*',
}

escrow_ignore {
    'config/*.lua',
    'bridge/*.lua',
    'bridge/**/*.lua',
    'locales/*.json',
    'sql/*.sql',
    'ITEMS_TO_ADD.lua',
    'README.md',
    'CHANGELOG.md',
    'LICENSE.txt',
}
