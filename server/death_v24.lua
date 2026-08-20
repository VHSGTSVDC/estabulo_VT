-- estabulo_VT v2.4.0 - morte e recuperação segura
LRRPDeathV24 = LRRPDeathV24 or {pending={}}

local function decode(v)
    local t=LRRP.SafeJsonDecode(v)
    return type(t)=='table' and t or {}
end
local function encode(v) return LRRP.SafeJsonEncode(v or {}) end
local function ident(src) return VORPAdapter.identity(src) end
local function mine(src,horseId)
    local id,cid=ident(src)
    if not id then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{
        tonumber(horseId),id,cid
    })
end
local function future(sqlDate)
    if not sqlDate then return false end
    local y,m,d,H,M,S=tostring(sqlDate):match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
    if not y then return false end
    return os.time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=tonumber(H),min=tonumber(M),sec=tonumber(S)})>os.time()
end
local function hasItem(src,item,amount)
    if not item or item=='' then return true end
    if VORPAdapter.hasItem then return VORPAdapter.hasItem(src,item,amount or 1) end
    return false
end
local function removeItem(src,item,amount)
    if VORPAdapter.removeItem then return VORPAdapter.removeItem(src,item,amount or 1) end
    return false
end

local function finalizeDeath(src,h)
    if not h or h.death_state~='critical' then return end
    local covered=Config.Death.allowInsuranceClaim and future(h.insurance_until)
    local newState=covered and 'claimable' or 'dead'
    DB.update([[
        UPDATE lrrp_horses
        SET death_state=?,life_stage='deceased',is_primary=0,health=0,
            critical_until=NULL,death_confirmations=0,updated_at=CURRENT_TIMESTAMP
        WHERE id=? AND death_state='critical'
    ]],{newState,h.id})
    LRRPDeathV24.pending[h.id]=nil
    VORPAdapter.notify(src,covered
        and '💀 Seu cavalo morreu, mas o seguro está ativo. Você pode acionar a apólice.'
        or '💀 Seu cavalo morreu permanentemente.')
    TriggerClientEvent('lrrp_stables:forceDismiss',src,h.id)
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end

RegisterNetEvent('lrrp_stables:criticalHorseV24',function(horseId)
    local src=source
    local h=mine(src,horseId)
    if not h or h.death_state~='alive' then return end

    local now=os.time()
    local p=LRRPDeathV24.pending[h.id]
    if p and now-p.last <= (Config.Death.confirmationWindowSeconds or 12) then
        p.count=p.count+1
        p.last=now
    else
        p={count=1,last=now}
        LRRPDeathV24.pending[h.id]=p
    end

    if p.count < (Config.Death.serverConfirmations or 2) then
        return
    end

    local untilAt=os.date('%Y-%m-%d %H:%M:%S',now+(Config.Death.criticalSeconds or 45))
    local hs=decode(h.health_state)
    hs.injury='severe'
    hs.critical=true
    hs.critical_until=untilAt

    DB.update([[
        UPDATE lrrp_horses
        SET death_state='critical',health=1,stamina=0,health_state=?,
            critical_until=?,death_confirmations=?,updated_at=CURRENT_TIMESTAMP
        WHERE id=? AND death_state='alive'
    ]],{encode(hs),untilAt,p.count,h.id})

    VORPAdapter.notify(src,('🚑 %s está em estado crítico! Você tem %d segundos para tentar recuperá-lo.'):format(
        tostring(h.name),Config.Death.criticalSeconds or 45
    ))
    TriggerClientEvent('lrrp_stables:horseCriticalClientV24',src,h.id,untilAt)
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

RegisterNetEvent('lrrp_stables:reviveCriticalHorseV24',function(horseId)
    local src=source
    local h=mine(src,horseId)
    if not h or h.death_state~='critical' then
        return VORPAdapter.notify(src,'Este cavalo não está em estado crítico.')
    end

    local item=Config.Death.criticalItem
    if Config.Death.requireCriticalItem and not hasItem(src,item,1) then
        return VORPAdapter.notify(src,'Você precisa de 1x '..tostring(item)..' para estabilizar o cavalo.')
    end
    if Config.Death.requireCriticalItem and not removeItem(src,item,1) then
        return VORPAdapter.notify(src,'Não foi possível consumir o medicamento.')
    end

    local hs=decode(h.health_state)
    hs.critical=nil
    hs.critical_until=nil
    hs.treated=true
    hs.recovery_started=os.date('%Y-%m-%d %H:%M:%S')
    hs.recovery_until=os.date('%Y-%m-%d %H:%M:%S',os.time()+35*60)

    DB.update([[
        UPDATE lrrp_horses
        SET death_state='alive',life_stage='adult',health=?,stamina=?,health_state=?,
            critical_until=NULL,death_confirmations=0,updated_at=CURRENT_TIMESTAMP
        WHERE id=? AND death_state='critical'
    ]],{
        Config.Death.criticalReviveHealth or 28,
        Config.Death.criticalReviveStamina or 22,
        encode(hs),h.id
    })

    LRRPDeathV24.pending[h.id]=nil
    VORPAdapter.notify(src,'❤️ Cavalo estabilizado. Ele sobreviveu, mas precisa se recuperar.')
    TriggerClientEvent('lrrp_stables:horseRevivedClientV24',src,h.id)
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

-- Substitui a morte instantânea antiga.
AddEventHandler('lrrp_stables:v7HealthSaved',function(src,horseId,health)
    if not Config.Death.permanent or tonumber(health)>0 then return end
    TriggerEvent('lrrp_stables:deathHealthZeroV24',src,horseId)
end)

AddEventHandler('lrrp_stables:deathHealthZeroV24',function(src,horseId)
    local h=mine(src,horseId)
    if not h or h.death_state~='alive' then return end
    local now=os.time()
    local p=LRRPDeathV24.pending[h.id]
    if p and now-p.last <= (Config.Death.confirmationWindowSeconds or 12) then
        p.count=p.count+1; p.last=now
    else
        p={count=1,last=now}; LRRPDeathV24.pending[h.id]=p
    end
    if p.count >= (Config.Death.serverConfirmations or 2) then
        TriggerClientEvent('lrrp_stables:requestCriticalConfirmV24',src,h.id)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local rows=DB.query([[
            SELECT * FROM lrrp_horses
            WHERE death_state='critical' AND critical_until IS NOT NULL
        ]],{}) or {}
        local now=os.time()
        for _,h in ipairs(rows) do
            local y,m,d,H,M,S=tostring(h.critical_until):match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
            if y then
                local t=os.time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=tonumber(H),min=tonumber(M),sec=tonumber(S)})
                if t<=now then
                    -- Owner may be offline; finalize safely in DB.
                    local covered=Config.Death.allowInsuranceClaim and future(h.insurance_until)
                    DB.update([[
                        UPDATE lrrp_horses SET death_state=?,life_stage='deceased',is_primary=0,
                        health=0,critical_until=NULL,death_confirmations=0,updated_at=CURRENT_TIMESTAMP
                        WHERE id=? AND death_state='critical'
                    ]],{covered and 'claimable' or 'dead',h.id})
                end
            end
        end
    end
end)
