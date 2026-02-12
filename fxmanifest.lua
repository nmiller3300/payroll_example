fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'MyBusiness Payroll'
description 'Enterprise payroll + employee tablet for QBCore'
version '1.2.0'

dependency 'qb-core'
dependency 'oxmysql'

shared_scripts {
    'config.lua',
    'permissions.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/app.js'
}
