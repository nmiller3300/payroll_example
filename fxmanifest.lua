fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'MyBusiness Payroll'
description 'QBCore payroll command dashboard with enterprise Command Yellow theme'
version '1.1.0'

shared_scripts {
    'config.lua'
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
