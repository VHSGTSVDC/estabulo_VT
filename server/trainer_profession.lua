-- estabulo_VT v1.8.0 - profissão treinador
LRRPTrainer = { offers={}, sessions={}, cooldown={} }

local function ownedHorse(src,horseId)
    local identifier,charId=VORPAdapter.identity(src)
    if not identifier then return nil end
    return DB.single(
        'SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',
        {tonumber(horseId),identifier,charId}
    )
end

local function disciplineDef(key)
    return Config.Release and Config.Release.disciplines and Config.Release.disciplines[tostring(key or '')]
end

local function online(src)
    return tonumber(src) and GetPlayerPing(tonumber(src))>0
end

local function refundOwner(owner,amount)
    if online(owner) and amount>0 then
        VORPAdapter.addCurrency(owner,Config.TrainerProfession.currency,amount)
        VORPAdapter.notify(owner,('Treinamento cancelado. $%d devolvidos.'):format(amount))
    end
end

RegisterNetEvent('lrrp_stables:trainerServiceRequest',function(horseId,discipline,target)
    local owner=source
    if not Config.TrainerProfession.enabled then return end

    target=tonumber(target)
    local horse=ownedHorse(owner,horseId)
    local def=disciplineDef(discipline)

    if not horse or not def then
        return VORPAdapter.notify(owner,'Cavalo ou disciplina inválida.')
    end
    if not target or target==owner or not online(target) then
        return VORPAdapter.notify(owner,'Treinador inválido ou offline.')
    end
    if not VORPAdapter.isTrainer(target) then
        return VORPAdapter.notify(owner,'Este jogador não possui a profissão de treinador.')
    end

    local cd=LRRPTrainer.cooldown[horse.id] or 0
    if cd>os.time() then
        return VORPAdapter.notify(owner,('Este cavalo poderá treinar novamente em %d segundo(s).'):format(cd-os.time()))
    end

    local token=('%s:%s:%s:%s'):format(owner,target,horse.id,math.random(100000,999999))
    LRRPTrainer.offers[token]={
        token=token,owner=owner,trainer=target,horseId=horse.id,
        horseName=horse.name,discipline=tostring(discipline),
        price=tonumber(Config.TrainerProfession.servicePrice) or 250,
        expires=os.time()+(tonumber(Config.TrainerProfession.offerTimeoutSeconds) or 30)
    }

    TriggerClientEvent('lrrp_stables:trainerServiceOffer',target,{
        token=token,owner=owner,horseId=horse.id,horseName=horse.name,
        discipline=tostring(discipline),disciplineLabel=def.label,
        price=Config.TrainerProfession.servicePrice
    })
    VORPAdapter.notify(owner,'Pedido enviado ao treinador. Aguarde a resposta.')
    print(('[estabulo_VT] TREINADOR OFERTA | dono=%s treinador=%s cavalo=%s disciplina=%s'):format(
        owner,target,horse.id,tostring(discipline)
    ))
end)

RegisterNetEvent('lrrp_stables:trainerServiceReply',function(token,accepted)
    local trainer=source
    local p=LRRPTrainer.offers[tostring(token or '')]
    if not p or p.trainer~=trainer then return end
    LRRPTrainer.offers[p.token]=nil

    if p.expires<os.time() or not online(p.owner) then
        return VORPAdapter.notify(trainer,'A oferta expirou ou o dono saiu do servidor.')
    end
    if not accepted then
        VORPAdapter.notify(trainer,'Serviço recusado.')
        return VORPAdapter.notify(p.owner,'O treinador recusou o serviço.')
    end
    if not VORPAdapter.isTrainer(trainer) then
        return VORPAdapter.notify(trainer,'Sua profissão não permite este serviço.')
    end

    local balance=VORPAdapter.balance(p.owner,Config.TrainerProfession.currency)
    if (tonumber(balance) or 0)<p.price then
        VORPAdapter.notify(trainer,'O cliente não possui saldo suficiente.')
        return VORPAdapter.notify(p.owner,'Saldo insuficiente para contratar o treinador.')
    end
    if not VORPAdapter.removeCurrency(p.owner,Config.TrainerProfession.currency,p.price) then
        return VORPAdapter.notify(p.owner,'Falha ao reservar o pagamento do treinador.')
    end

    local sessionToken=('train:%s:%s'):format(p.token,math.random(1000,9999))
    LRRPTrainer.sessions[sessionToken]={
        token=sessionToken,owner=p.owner,trainer=trainer,horseId=p.horseId,
        horseName=p.horseName,discipline=p.discipline,price=p.price,
        expires=os.time()+(tonumber(Config.TrainerProfession.trainingTimeoutSeconds) or 120)
    }

    VORPAdapter.notify(p.owner,('Treinador aceitou. $%d reservados até a conclusão.'):format(p.price))
    TriggerClientEvent('lrrp_stables:startProfessionalTraining',trainer,{
        token=sessionToken,horseId=p.horseId,horseName=p.horseName,
        discipline=p.discipline,disciplineLabel=(disciplineDef(p.discipline) or {}).label,
        rounds=6
    })
end)

RegisterNetEvent('lrrp_stables:completeProfessionalTraining',function(token,score)
    local trainer=source
    local s=LRRPTrainer.sessions[tostring(token or '')]
    if not s or s.trainer~=trainer then return end
    LRRPTrainer.sessions[s.token]=nil

    if s.expires<os.time() or not online(s.owner) then
        refundOwner(s.owner,s.price)
        return VORPAdapter.notify(trainer,'Sessão expirada.')
    end

    score=math.max(0,math.min(100,tonumber(score) or 0))
    local minScore=tonumber(Config.TrainerProfession.minScore) or 50

    if score<minScore then
        refundOwner(s.owner,s.price)
        VORPAdapter.notify(trainer,('Treino falhou: %d/%d. Sem pagamento.'):format(score,minScore))
        return
    end

    local horse=ownedHorse(s.owner,s.horseId)
    local def=disciplineDef(s.discipline)
    if not horse or not def then
        refundOwner(s.owner,s.price)
        return VORPAdapter.notify(trainer,'O cavalo não está mais disponível.')
    end

    local disciplines=LRRP.SafeJsonDecode(horse.disciplines)
    if type(disciplines)~='table' then disciplines={} end
    local old=tonumber(disciplines[s.discipline]) or 0
    disciplines[s.discipline]=math.min(tonumber(def.maxLevel) or 10,old+1)

    local xp=(tonumber(def.xp) or 0)+(tonumber(Config.TrainerProfession.xpBonus) or 0)
    local training=(tonumber(def.trainingGain) or 0)+(tonumber(Config.TrainerProfession.trainingGain) or 0)

    DB.update([[
        UPDATE lrrp_horses
        SET disciplines=?,training=LEAST(100,training+?),xp=xp+?,updated_at=CURRENT_TIMESTAMP
        WHERE id=?
    ]],{LRRP.SafeJsonEncode(disciplines),training,xp,horse.id})

    -- recalcula bonding com o novo XP
    local updated=DB.single('SELECT xp FROM lrrp_horses WHERE id=?',{horse.id})
    if updated then
        DB.update('UPDATE lrrp_horses SET bonding=? WHERE id=?',{
            LRRP.BondingFromXP(updated.xp),horse.id
        })
    end

    VORPAdapter.addCurrency(trainer,Config.TrainerProfession.currency,Config.TrainerProfession.trainerPayout)
    LRRPTrainer.cooldown[horse.id]=os.time()+(tonumber(Config.TrainerProfession.cooldownSeconds) or 180)

    VORPAdapter.notify(trainer,('Treino concluído! Nota %d. Pagamento: $%d.'):format(
        score,Config.TrainerProfession.trainerPayout
    ))
    VORPAdapter.notify(s.owner,('%s evoluiu em %s para nível %d.'):format(
        tostring(horse.name),tostring(def.label),disciplines[s.discipline]
    ))

    TriggerClientEvent('lrrp_stables:refreshV10',s.owner)
    TriggerClientEvent('lrrp_stables:refreshV6',s.owner)

    print(('[estabulo_VT] TREINADOR OK | dono=%s treinador=%s cavalo=%s disciplina=%s nivel=%s nota=%s'):format(
        s.owner,trainer,horse.id,s.discipline,disciplines[s.discipline],score
    ))
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now=os.time()
        for token,p in pairs(LRRPTrainer.offers) do
            if p.expires<now then
                LRRPTrainer.offers[token]=nil
                if online(p.owner) then VORPAdapter.notify(p.owner,'Pedido ao treinador expirou.') end
                if online(p.trainer) then VORPAdapter.notify(p.trainer,'Oferta de treinamento expirou.') end
            end
        end
        for token,s in pairs(LRRPTrainer.sessions) do
            if s.expires<now then
                LRRPTrainer.sessions[token]=nil
                refundOwner(s.owner,s.price)
                if online(s.trainer) then VORPAdapter.notify(s.trainer,'Sessão de treinamento expirou.') end
            end
        end
    end
end)

AddEventHandler('playerDropped',function()
    local src=source
    for token,p in pairs(LRRPTrainer.offers) do
        if p.owner==src or p.trainer==src then LRRPTrainer.offers[token]=nil end
    end
    for token,s in pairs(LRRPTrainer.sessions) do
        if s.trainer==src then
            LRRPTrainer.sessions[token]=nil
            refundOwner(s.owner,s.price)
        end
    end
end)
