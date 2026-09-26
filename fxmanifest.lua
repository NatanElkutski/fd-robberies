fx_version '3.6.0'
game 'gta5'
lua54 'yes'
author 'FIVE DEV'
description 'FD Robberies - Exclusive QBCore robbery network by FIVE DEV'
version '3.6.8'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}
client_scripts {'client.lua'}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
files {
    'html/index.html','html/style.css','html/app.js','html/img/*','html/avatars/*','html/assets/heists/*','html/assets/avatars/*','html/assets/shop/*'
}

dependencies {'qb-core','oxmysql','ox_lib'}

escrow_ignore {
    'config.lua',
    'README.md',
    'LICENSE.txt',
    'KEYMASTER-UPLOAD.txt',
    'install.sql',
    'ITEMS_TO_ADD.lua'
}
