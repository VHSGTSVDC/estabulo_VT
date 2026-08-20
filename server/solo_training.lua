-- estabulo_VT v1.9.0 - treinamento solo
local SoloSessions={}
local SoloCooldown={}

local function owned(src,id)
    local identifier,charId=VORPAdapter.identity(src)
    if not identifier then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{
        tonumber(id),identifier,charId
    })
end

local function discipline(key)
    return Config.Release and Config.Release.disciplines and Config.Release.disciplines[tostring(key or '')]
end

RegisterNetEvent('lrrp_stables:startSoloTraining',function(horseId,disciplineKey)
    local src=source
    if not Config.SoloTraining.enabled then return end

    local h=owned(src,horseId)
    local def=discipline(disciplineKey)
    if not h or not def then return VORPAdapter.notify(src,'Cavalo ou disciplina inválida.') end
    if h.death_state~='alive' then return VORPAdapter.notify(src,'Este cavalo não pode treinar.') end
    if h.life_stage~='adult' then return VORPAdapter.notify(src,'Somente cavalos adultos podem fazer treino avançado.') end

    local cd=SoloCooldown[h.id] or 0
    if cd>os.time() then
        return VORPAdapter.notify(src,('Aguarde %d segundo(s) para treinar novamente.'):format(cd-os.time()))
    end

    if (tonumber(h.stamina) or 0)<(Config.SoloTraining.staminaCost or 8) then
        return VORPAdapter.notify(src,'Seu cavalo está cansado demais para treinar.')
    end
    if (tonumber(h.hunger) or 0)<15 or (tonumber(h.thirst) or 0)<15 then
        return VORPAdapter.notify(src,'Alimente e dê água ao cavalo antes do treino.')
    end

    local token=('solo:%s:%s:%s'):format(src,h.id,math.random(100000,999999))
    SoloSessions[token]={
        owner=src,horseId=h.id,discipline=tostring(disciplineKey),
        expires=os.time()+120
    }

    TriggerClientEvent('lrrp_stables:startSoloTrainingClient',src,{
        token=token,horseId=h.id,horseName=h.name,
        discipline=tostring(disciplineKey),disciplineLabel=def.label,
        rounds=Config.SoloTraining.rounds or 6
    })
end)

RegisterNetEvent('lrrp_stables:finishSoloTraining',function(token,score)
    local src=source
    local s=SoloSessions[tostring(token or '')]
    if not s or s.owner~=src then return end
    SoloSessions[token]=nil
    if s.expires<os.time() then return VORPAdapter.notify(src,'O treinamento expirou.') end

    local h=owned(src,s.horseId)
    local def=discipline(s.discipline)
    if not h or not def then return end

    score=math.max(0,math.min(100,tonumber(score) or 0))
    local stamina=math.max(0,(tonumber(h.stamina) or 0)-(Config.SoloTraining.staminaCost or 8))
    local hunger=math.max(0,(tonumber(h.hunger) or 0)-(Config.SoloTraining.hungerCost or 3))
    local thirst=math.max(0,(tonumber(h.thirst) or 0)-(Config.SoloTraining.thirstCost or 5))

    if score<(Config.SoloTraining.minScore or 50) then
        DB.update('UPDATE lrrp_horses SET stamina=?,hunger=?,thirst=? WHERE id=?',{
            stamina,hunger,thirst,h.id
        })
        SoloCooldown[h.id]=os.time()+math.floor((Config.SoloTraining.cooldownSeconds or 120)/2)
        TriggerClientEvent('lrrp_stables:refreshV6',src)
        return VORPAdapter.notify(src,('Treino incompleto: nota %d. Tente novamente depois.'):format(score))
    end

    local disciplines=LRRP.SafeJsonDecode(h.disciplines)
    if type(disciplines)~='table' then disciplines={} end
    local old=tonumber(disciplines[s.discipline]) or 0
    local gain=tonumber(Config.SoloTraining.disciplineGain) or 1
    disciplines[s.discipline]=math.min(tonumber(def.maxLevel) or 10,old+gain)

    local quality=score/100.0
    local xp=math.floor((Config.SoloTraining.xpBase or 18)+(tonumber(def.xp) or 0)*quality)
    local trainGain=math.max(1,math.floor((Config.SoloTraining.trainingBase or 2)+(tonumber(def.trainingGain) or 0)*quality))

    DB.update([[
        UPDATE lrrp_horses SET disciplines=?,training=LEAST(100,training+?),xp=xp+?,
        stamina=?,hunger=?,thirst=?,updated_at=CURRENT_TIMESTAMP WHERE id=?
    ]],{
        LRRP.SafeJsonEncode(disciplines),trainGain,xp,stamina,hunger,thirst,h.id
    })

    local updated=DB.single('SELECT xp,bonding FROM lrrp_horses WHERE id=?',{h.id})
    if updated then
        local newBond=LRRP.BondingFromXP(updated.xp)
        DB.update('UPDATE lrrp_horses SET bonding=? WHERE id=?',{newBond,h.id})
        if newBond>(tonumber(h.bonding) or 1) then
            local benefit=Config.BondingBenefits[newBond] or {}
            TriggerClientEvent('lrrp_stables:bondingLevelUp',src,{
                level=newBond,label=benefit.label,healthBonus=benefit.healthBonus,
                staminaBonus=benefit.staminaBonus,whistleDistance=benefit.whistleDistance
            })
        end
    end

    SoloCooldown[h.id]=os.time()+(Config.SoloTraining.cooldownSeconds or 120)
    VORPAdapter.notify(src,('🏇 Treino concluído! Nota %d • %s nível %d • +%d XP'):format(
        score,tostring(def.label),disciplines[s.discipline],xp
    ))
    TriggerClientEvent('lrrp_stables:refreshV10',src)
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)
