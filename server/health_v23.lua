-- estabulo_VT v2.3.0 - ferimentos, veterinário e recuperação
LRRPHealthV23 = LRRPHealthV23 or {}

local function decode(v)
    local t=LRRP.SafeJsonDecode(v)
    return type(t)=='table' and t or {}
end
local function encode(v) return LRRP.SafeJsonEncode(v or {}) end

local function ident(src)
    return VORPAdapter.identity(src)
end

local function owned(src,horseId)
    local id,cid=ident(src)
    if not id then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{
        tonumber(horseId),id,cid
    })
end

local function sqlTime(minutes)
    return os.date('%Y-%m-%d %H:%M:%S',os.time()+math.floor((tonumber(minutes) or 0)*60))
end

local function parseSql(v)
    if not v then return nil end
    local y,m,d,H,M,S=tostring(v):match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
    if not y then return nil end
    return os.time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=tonumber(H),min=tonumber(M),sec=tonumber(S)})
end

local rank={light=1,leg=2,severe=3}

local function injuryForHealth(pct)
    pct=tonumber(pct) or 100
    if pct<=25 then return 'severe' end
    if pct<=50 then return 'leg' end
    if pct<=75 then return 'light' end
    return nil
end

RegisterNetEvent('lrrp_stables:reportHorseDamageV23',function(horseId,healthPct)
    local src=source
    if not Config.InjurySystem.enabled then return end

    local h=owned(src,horseId)
    if not h or h.death_state~='alive' then return end

    healthPct=math.max(1,math.min(100,tonumber(healthPct) or 100))
    local injury=injuryForHealth(healthPct)
    if not injury then
        -- ainda salva a vida percentual sem criar ferimento
        DB.update('UPDATE lrrp_horses SET health=LEAST(health,?),updated_at=CURRENT_TIMESTAMP WHERE id=?',{
            healthPct,h.id
        })
        return
    end

    local state=decode(h.health_state)
    local current=tostring(state.injury or '')
    if (rank[injury] or 0) >= (rank[current] or 0) then
        state.injury=injury
        state.injury_since=os.date('%Y-%m-%d %H:%M:%S')
        state.recovery_until=nil
        state.treated=false
    end

    DB.update('UPDATE lrrp_horses SET health=?,health_state=?,updated_at=CURRENT_TIMESTAMP WHERE id=?',{
        math.min(tonumber(h.health) or 100,healthPct),encode(state),h.id
    })

    local def=Config.InjurySystem.severity[injury] or {}
    VORPAdapter.notify(src,('🩹 %s sofreu: %s.'):format(tostring(h.name),tostring(def.label or injury)))
    TriggerClientEvent('lrrp_stables:horseHealthStateV23',src,h.id,state)
    TriggerClientEvent('lrrp_stables:refreshV6',src)

    print(('[estabulo_VT] FERIMENTO | src=%s cavalo=%s tipo=%s vida=%.1f'):format(
        tostring(src),tostring(h.id),injury,healthPct
    ))
end)

RegisterNetEvent('lrrp_stables:healthStatusV23',function(horseId)
    local src=source
    local h=owned(src,horseId)
    if not h then return end
    TriggerClientEvent('lrrp_stables:healthStatusClientV23',src,{
        id=h.id,name=h.name,health=h.health,stamina=h.stamina,
        health_state=decode(h.health_state),death_state=h.death_state
    })
end)

-- Chamado pelo tratamento normal da aba Saúde.
LRRPStartRecoveryV23=function(src,horseId)
    local h=owned(src,horseId)
    if not h then return false end

    local state=decode(h.health_state)
    if not next(state) then return false end

    local injury=tostring(state.injury or '')
    local def=Config.InjurySystem.severity[injury]
    local minutes=def and def.recoveryMinutes or Config.InjurySystem.diseaseRecoveryMinutes or 15

    state.treated=true
    state.recovery_started=os.date('%Y-%m-%d %H:%M:%S')
    state.recovery_until=sqlTime(minutes)

    local targetHealth=def and def.treatmentHealth or 78
    local targetStamina=def and def.treatmentStamina or 72

    DB.update([[
        UPDATE lrrp_horses
        SET health_state=?,health=GREATEST(health,?),stamina=GREATEST(stamina,?),
            updated_at=CURRENT_TIMESTAMP
        WHERE id=?
    ]],{encode(state),targetHealth,targetStamina,h.id})

    TriggerClientEvent('lrrp_stables:horseHealthStateV23',src,h.id,state)
    return true,state
end

CreateThread(function()
    while true do
        Wait((Config.InjurySystem.recoveryTickSeconds or 30)*1000)

        if Config.InjurySystem.enabled then
            local rows=DB.query([[
                SELECT id,health,stamina,health_state
                FROM lrrp_horses
                WHERE death_state='alive' AND health_state IS NOT NULL AND health_state<>'{}'
            ]],{}) or {}

            for _,h in ipairs(rows) do
                local state=decode(h.health_state)
                if state.treated and state.recovery_until then
                    local untilAt=parseSql(state.recovery_until)

                    if untilAt and untilAt<=os.time() then
                        -- Recuperação concluída.
                        DB.update([[
                            UPDATE lrrp_horses
                            SET health_state='{}',
                                health=LEAST(100,GREATEST(health,90)),
                                stamina=LEAST(100,GREATEST(stamina,90)),
                                updated_at=CURRENT_TIMESTAMP
                            WHERE id=?
                        ]],{h.id})
                    else
                        -- Recuperação gradual enquanto o tempo corre.
                        DB.update([[
                            UPDATE lrrp_horses
                            SET health=LEAST(100,health+?),
                                stamina=LEAST(100,stamina+?),
                                updated_at=CURRENT_TIMESTAMP
                            WHERE id=?
                        ]],{
                            Config.InjurySystem.recoveryHealthPerTick or 2,
                            Config.InjurySystem.recoveryStaminaPerTick or 2,
                            h.id
                        })
                    end
                end
            end
        end
    end
end)
