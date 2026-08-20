DB = {}
local function oxAvailable() return GetResourceState('oxmysql') == 'started' and MySQL end

function DB.query(sql, params)
    if oxAvailable() and MySQL.query and MySQL.query.await then return MySQL.query.await(sql, params or {}) end
    error('[LRRP_Stables] oxmysql é necessário nesta versão. Instale/inicie oxmysql antes do LRRP_Stables.')
end
function DB.single(sql, params)
    if oxAvailable() and MySQL.single and MySQL.single.await then return MySQL.single.await(sql, params or {}) end
    local rows = DB.query(sql, params); return rows and rows[1] or nil
end
function DB.insert(sql, params)
    if oxAvailable() and MySQL.insert and MySQL.insert.await then return MySQL.insert.await(sql, params or {}) end
    error('[LRRP_Stables] oxmysql indisponível.')
end
function DB.update(sql, params)
    if oxAvailable() and MySQL.update and MySQL.update.await then return MySQL.update.await(sql, params or {}) end
    error('[LRRP_Stables] oxmysql indisponível.')
end
