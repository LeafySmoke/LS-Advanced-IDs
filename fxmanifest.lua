-- fxmanifest.lua (updated)
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'LeafySmoke'
description 'Advanced Multi-Card ID System with Photos & Fakes - Standalone/ESX/QB Compatible'
version '3.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/ui.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'  -- Player photos & default.png (add your own default)
}

dependencies {
    'screenshot-basic'  -- Required for auto-photos. Install: https://github.com/citizenfx/screenshot-basic
}