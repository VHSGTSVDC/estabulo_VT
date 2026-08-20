-- estabulo_VT v3.0.0 FINAL
LRRPRelease = {
    version = '3.0.0',
    name = 'estabulo_VT',
    schemaOk = false
}

local requiredHorseColumns = {
    'id','identifier','charidentifier','name','model','is_primary',
    'health','stamina','hunger','thirst','cleanliness','xp','bonding','training',
    'sex','birth_at','father_id','mother_id','genetics','life_stage','rarity',
    'death_state','wild_origin','temperament','health_state',
    'critical_until','death_confirmations'
}

local function tableExists(name)
    local row=MySQL.single.await([[
        SELECT COUNT(*) AS total
        FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = ?
    ]],{name})
    return row and tonumber(row.total or 0)>0
end

local function columnMap(tableName)
    local rows=MySQL.query.await([[
        SELECT COLUMN_NAME
        FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = ?
    ]],{tableName}) or {}
    local out={}
    for _,r in ipairs(rows) do out[tostring(r.COLUMN_NAME)]=true end
    return out
end

local function startupCheck()
    Wait(1500)

    print('^2============================================================^7')
    print('^2[estabulo_VT] v3.0.0 FINAL iniciando...^7')

    if not tableExists('lrrp_horses') then
        print('^1[estabulo_VT] ERRO: tabela lrrp_horses não existe.^7')
        print('^3[estabulo_VT] Execute sql/INSTALL_FINAL_V3.sql no banco.^7')
        print('^2============================================================^7')
        return
    end

    local cols=columnMap('lrrp_horses')
    local missing={}
    for _,name in ipairs(requiredHorseColumns) do
        if not cols[name] then missing[#missing+1]=name end
    end

    if #missing>0 then
        print(('^1[estabulo_VT] BANCO INCOMPLETO: faltam %d coluna(s): %s^7'):format(
            #missing,table.concat(missing,', ')
        ))
        print('^3[estabulo_VT] Execute sql/INSTALL_FINAL_V3.sql antes de usar o resource.^7')
        print('^2============================================================^7')
        return
    end

    LRRPRelease.schemaOk=true
    print('^2[estabulo_VT] Banco de dados: OK^7')
    print('^2[estabulo_VT] VORP Core: '..GetResourceState('vorp_core')..'^7')
    print('^2[estabulo_VT] VORP Inventory: '..GetResourceState('vorp_inventory')..'^7')
    print('^2[estabulo_VT] oxmysql: '..GetResourceState('oxmysql')..'^7')
    print('^2[estabulo_VT] v3.0.0 FINAL carregada com sucesso.^7')
    print('^2============================================================^7')
end

CreateThread(startupCheck)

RegisterCommand('estabulostatus',function(src)
    if src~=0 and not IsPlayerAceAllowed(src,'estabulo.admin') then return end

    local horseCount=tonumber((MySQL.single.await(
        'SELECT COUNT(*) AS total FROM lrrp_horses'
    ) or {}).total) or 0

    local criticalCount=tonumber((MySQL.single.await(
        "SELECT COUNT(*) AS total FROM lrrp_horses WHERE death_state='critical'"
    ) or {}).total) or 0

    local msg=('[estabulo_VT v3.0.0] schema=%s cavalos=%d criticos=%d inventory=%s'):format(
        tostring(LRRPRelease.schemaOk),
        horseCount,
        criticalCount,
        GetResourceState('vorp_inventory')
    )

    if src==0 then
        print(msg)
    else
        TriggerClientEvent('lrrp_stables:notify',src,msg)
    end
end,false)
