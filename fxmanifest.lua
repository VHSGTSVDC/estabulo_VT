fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'Victor Winchester'
description 'estabulo_VT v3.0.5 PUBLIC HORSE BLIPS - RedM VORP Stable System'
version '3.0.5'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_scripts {
    'locales/pt_br.lua',
    'config.lua',
    'shared/horse_catalog.lua',
    'shared/utils.lua',
    'shared/accessory_catalog.lua'
}

server_scripts {
    'server/public_release_credit.lua',
    'server/supply_shop.lua',
    'server/release_v300.lua',
    'server/security_v25.lua',
    'server/death_v24.lua',
    'server/health_v23.lua',
    'server/temperament.lua',
    'server/solo_training.lua',
    'server/trainer_profession.lua',
    'server/version.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/adapter_vorp.lua',
    'integrations/vorp_inventory.lua',
    'server/main.lua',
    'server/trainer.lua',
    'server/v6_features.lua',
    'server/v7_features.lua',
    'server/v8_features.lua',
    'server/v9_features.lua',
    'server/v10_release.lua'
}

client_scripts {
    'client/horse_blips.lua',
    'client/supply_shop.lua',
    'client/death_v24.lua',
    'client/health_v23.lua',
    'client/temperament.lua',
    'client/solo_training.lua',
    'client/trainer_profession.lua',
    'client/version.lua',
    'client/horse.lua',
    'client/accessories.lua',
    'client/showroom.lua',
    'client/cinematic.lua',
    'client/vendors.lua',
    'client/interactions.lua',
    'client/main.lua',
    'client/ui.lua',
    'client/v6_features.lua',
    'client/v7_features.lua',
    'client/v8_features.lua',
    'client/v9_features.lua',
    'client/v10_release.lua'
}

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory'
}
