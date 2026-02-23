fx_version "cerulean"
game "gta5"
lua54 "yes"

author 'Lexo'
description 'CM - Pizza Delivery'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/sh_config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies {
    'ox_lib'
}

files {
    'stream/*.ydr'
}