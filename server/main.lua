local function owner(src)
    local identifier, charid, c = VORPAdapter.identity(src)
    return identifier, charid, c
end
local function maxHorses(src) return VORPAdapter.isTrainer(src) and Config.TrainerMaxHorses or Config.MaxHorses end
local function getOwned(src, horseId)
    local id, cid = owner(src); if not id then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?', {horseId,id,cid})
end
local function serialize(row)
    if not row then return nil end
    row.accessories = LRRP.SafeJsonDecode(row.accessories)
    row.weapon_storage = LRRP.SafeJsonDecode(row.weapon_storage)
    row.upgrades = LRRP.SafeJsonDecode(row.upgrades)
    row.genetics = LRRP.SafeJsonDecode(row.genetics)
    row.health_state = LRRP.SafeJsonDecode(row.health_state)
    row.disciplines = LRRP.SafeJsonDecode(row.disciplines)
    row.horseshoe_durability = tonumber(row.horseshoe_durability) or 100
    row.catalog = LRRPHorseFind(row.model)
    row.breed_stats = LRRPHorseStats(row.catalog or row.model)
    return row
end
local function ownedAccessories(id,cid)
    local rows=DB.query('SELECT category,component_hash FROM lrrp_stable_accessories WHERE identifier=? AND charidentifier=?',{id,cid}) or {}
    local result={}
    for _,r in ipairs(rows) do
        result[r.category]=result[r.category] or {}
        result[r.category][tostring(r.component_hash):upper()]=true
    end
    return result
end
local function claimLegacyAccessories(id,cid,horses)
    for _,h in ipairs(horses or {}) do
        local accessories=type(h.accessories)=='table' and h.accessories or LRRP.SafeJsonDecode(h.accessories)
        for category,component in pairs(accessories) do
            component=tostring(component or '0'):upper()
            if component~='0' and LRRPAccessoryFind(category,component) then
                DB.insert('INSERT IGNORE INTO lrrp_stable_accessories(identifier,charidentifier,category,component_hash,price_paid,currency) VALUES(?,?,?,?,0,0)',{id,cid,category,component})
            end
        end
    end
end
local function sendUIData(src)
    local id,cid=owner(src); if not id then return end
    local rows=DB.query('SELECT * FROM lrrp_horses WHERE identifier=? AND charidentifier=? ORDER BY is_primary DESC,id ASC',{id,cid}) or {}
    for i=1,#rows do rows[i]=serialize(rows[i]) end
    claimLegacyAccessories(id,cid,rows)
    TriggerClientEvent('lrrp_stables:uiData',src,{horses=rows,ownedAccessories=ownedAccessories(id,cid)})
end


RegisterNetEvent('lrrp_stables:whistleRequest',function()
    local src=source
    local id,cid=owner(src)
    if not id then
        return TriggerClientEvent('lrrp_stables:whistleHorse',src,nil)
    end

    local row=DB.single([[
        SELECT * FROM lrrp_horses
        WHERE identifier=? AND charidentifier=?
          AND COALESCE(death_state,'alive') NOT IN ('dead','claimable')
          AND COALESCE(life_stage,'adult') <> 'deceased'
        ORDER BY is_primary DESC,id ASC
        LIMIT 1
    ]],{id,cid})

    if not row then
        print(('[estabulo_VT] ASSOBIO: nenhum cavalo disponível | src=%s char=%s'):format(
            tostring(src),tostring(cid)
        ))
        return TriggerClientEvent('lrrp_stables:whistleHorse',src,nil)
    end

    row=serialize(row)
    print(('[estabulo_VT] ASSOBIO: enviando cavalo | src=%s id=%s nome=%s principal=%s'):format(
        tostring(src),tostring(row.id),tostring(row.name),tostring(row.is_primary)
    ))
    TriggerClientEvent('lrrp_stables:whistleHorse',src,row)
end)

RegisterNetEvent('lrrp_stables:requestHorses', function() local src=source; if not LRRPGuard.allow(src,'ui_horses',Config.Performance.uiRequestMinMs) then return end; sendUIData(src) end)
RegisterNetEvent('lrrp_stables:requestUIData', function() local src=source; if not LRRPGuard.allow(src,'ui_data',Config.Performance.uiRequestMinMs) then return end; sendUIData(src) end)

RegisterNetEvent('lrrp_stables:buy', function(model,name,sex)
    local src=source
    if not LRRPGuard.allow(src,'buy_horse',Config.Performance.purchaseMinMs) then return end
    if not LRRPGuard.lock(src,'buy_horse',4000) then return end
    local id,cid=owner(src)
    if not id then return end

    local choice=LRRPHorseFind(tostring(model or ''))
    if not choice then
        return VORPAdapter.notify(src,Lang.invalidModel)
    end

    local okCount, n = pcall(function()
        return DB.single(
            'SELECT COUNT(*) AS total FROM lrrp_horses WHERE identifier=? AND charidentifier=?',
            {id,cid}
        )
    end)

    if not okCount then
        print(('[estabulo_VT] ERRO MYSQL AO CONTAR CAVALOS | %s'):format(tostring(n)))
        return VORPAdapter.notify(src,'Erro no banco de dados do estábulo. Veja o console.')
    end

    local total = n and tonumber(n.total) or 0
    if total >= maxHorses(src) then
        return VORPAdapter.notify(src,Lang.maxHorses)
    end

    local currency = tonumber(choice.currency) or 0
    local price = tonumber(choice.price) or 0

    -- Primeiro apenas confirma o saldo.
    local saldo = VORPAdapter.balance(src, currency)
    print(('[estabulo_VT] COMPRA CAVALO | modelo=%s saldo=%.2f preco=%.2f moeda=%d'):format(
        tostring(choice.model), tonumber(saldo) or 0, price, currency
    ))

    if (tonumber(saldo) or 0) + 0.0001 < price then
        return VORPAdapter.notify(src, currency==1 and 'Ouro insuficiente.' or Lang.noMoney)
    end

    -- Cobra usando a API oficial do VORP.
    if not VORPAdapter.removeCurrency(src,currency,price) then
        return VORPAdapter.notify(src,'Falha ao processar o pagamento. Veja o console do servidor.')
    end

    local primary = total == 0 and 1 or 0
    sex=tostring(sex or 'male'):lower()
    if sex~='male' and sex~='female' then sex='male' end

    local okInsert, horseId = pcall(function()
        return DB.insert([[INSERT INTO lrrp_horses
        (identifier,charidentifier,name,model,is_primary,price,purchase_currency,
         health,stamina,hunger,thirst,cleanliness,xp,bonding,training,
         accessories,weapon_storage,sex,birth_at,genetics,health_state,life_stage)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),'{}','{}','adult')]],
        {
            id,cid,LRRPGuard.text(name or choice.label,32),choice.model,primary,
            price,currency,100,100,100,100,100,0,0,0,'{}','{}',sex
        })
    end)

    if not okInsert or not horseId then
        print(('[estabulo_VT] ERRO MYSQL AO COMPRAR CAVALO | modelo=%s | erro=%s'):format(
            tostring(choice.model), tostring(horseId)
        ))

        -- Devolve o valor se o banco falhar depois da cobrança.
        local refunded = VORPAdapter.addCurrency(src,currency,price)
        print(('[estabulo_VT] REFUNDO APÓS ERRO MYSQL | valor=%.2f | sucesso=%s'):format(
            price, tostring(refunded)
        ))

        return VORPAdapter.notify(
            src,
            'O pagamento foi cancelado porque o banco não conseguiu salvar o cavalo. Valor devolvido.'
        )
    end

    print(('[estabulo_VT] CAVALO COMPRADO OK | id=%s | modelo=%s | sexo=%s | preco=%.2f'):format(
        tostring(horseId), tostring(choice.model), tostring(sex), price
    ))

    VORPAdapter.notify(src,Lang.bought)
    sendUIData(src)
end)

RegisterNetEvent('lrrp_stables:setPrimary', function(horseId)
    local src=source; local h=getOwned(src,tonumber(horseId)); if not h then return VORPAdapter.notify(src,Lang.noHorse) end
    local id,cid=owner(src)
    DB.update('UPDATE lrrp_horses SET is_primary=0 WHERE identifier=? AND charidentifier=?',{id,cid})
    DB.update('UPDATE lrrp_horses SET is_primary=1 WHERE id=?',{h.id})
    VORPAdapter.notify(src,Lang.primary); sendUIData(src)
end)

RegisterNetEvent('lrrp_stables:saveState',function(data)
    local src=source
    if type(data)~='table' then return end
    if not LRRPGuard.allow(src,'save_state',Config.Performance.saveStateMinMs) then return end

    local horseId=math.floor(LRRPGuard.number(data.id,1,2147483647,0))
    local h=getOwned(src,horseId)
    if not h then return end

    local health=LRRPGuard.number(data.health,0,200,h.health)
    local stamina=LRRPGuard.number(data.stamina,0,200,h.stamina)
    local hunger=LRRPGuard.number(data.hunger,0,100,h.hunger)
    local thirst=LRRPGuard.number(data.thirst,0,100,h.thirst)
    local cleanliness=LRRPGuard.number(data.cleanliness,0,100,h.cleanliness)
    local xp=math.floor(LRRPGuard.number(data.xp,0,10000000,h.xp))
    local training=math.floor(LRRPGuard.number(data.training,0,100,h.training))

    -- Coordenadas absurdas/NaN são descartadas; mantém a última posição válida.
    local x=LRRPGuard.number(data.x,-10000,10000,h.last_x or 0)
    local y=LRRPGuard.number(data.y,-10000,10000,h.last_y or 0)
    local z=LRRPGuard.number(data.z,-1000,3000,h.last_z or 0)

    DB.update([[UPDATE lrrp_horses
        SET health=?,stamina=?,hunger=?,thirst=?,cleanliness=?,xp=?,bonding=?,training=?,
            last_x=?,last_y=?,last_z=?,updated_at=CURRENT_TIMESTAMP
        WHERE id=? AND identifier=? AND charidentifier=?]],{
        health,stamina,hunger,thirst,cleanliness,xp,LRRP.BondingFromXP(xp),training,
        x,y,z,h.id,h.identifier,h.charidentifier
    })

    TriggerEvent('lrrp_stables:v7HealthSaved',src,h.id,health)
end)

RegisterNetEvent('lrrp_stables:needsTick',function(horseId)
    local src=source
    if not LRRPGuard.allow(src,'needs_tick',Config.Performance.needsTickMinMs) then return end
    local h=getOwned(src,tonumber(horseId))
    if not h then return end

    local hunger=LRRP.Clamp((tonumber(h.hunger) or 100)-(tonumber(Config.NeedDecay.hunger) or 0),0,100)
    local thirst=LRRP.Clamp((tonumber(h.thirst) or 100)-(tonumber(Config.NeedDecay.thirst) or 0),0,100)
    local clean=LRRP.Clamp((tonumber(h.cleanliness) or 100)-(tonumber(Config.NeedDecay.cleanliness) or 0),0,100)
    local health=tonumber(h.health) or 100

    if hunger<15 or thirst<15 then
        health=LRRP.Clamp(health-1,0,200)
    end

    DB.update([[
        UPDATE lrrp_horses
        SET health=?,hunger=?,thirst=?,cleanliness=?,updated_at=CURRENT_TIMESTAMP
        WHERE id=? AND identifier=? AND charidentifier=?
    ]],{
        health,hunger,thirst,clean,h.id,h.identifier,h.charidentifier
    })

    TriggerClientEvent('lrrp_stables:needsUpdated',src,h.id,{
        health=health,
        hunger=hunger,
        thirst=thirst,
        cleanliness=clean
    })

    LRRPGuard.debug('NEEDS | id=%s fome=%.1f sede=%.1f limpeza=%.1f',
        tostring(h.id),hunger,thirst,clean)
end)

local function careInventoryCount(src,item)
    if GetResourceState(Config.Inventory.resource or 'vorp_inventory')~='started' then return 0 end
    local ok,res=pcall(function() return exports.vorp_inventory:getItem(src,item) end)
    return ok and res and (tonumber(res.count) or 0) or 0
end

local function careInventorySub(src,item,amount)
    amount=math.max(1,math.floor(tonumber(amount) or 1))
    if careInventoryCount(src,item)<amount then return false end
    local ok,res=pcall(function() return exports.vorp_inventory:subItem(src,item,amount) end)
    return ok and res~=false
end

RegisterNetEvent('lrrp_stables:action', function(horseId, action)
    local src=source
    if not LRRPGuard.allow(src,'horse_action',700) then return end; local h=getOwned(src,tonumber(horseId)); local a=Config.Actions[action]
    if not h or not a then return end

    -- Cuidados físicos usam itens reais do VORP Inventory.
    local item=nil
    if action=='brush' then item=Config.Items.brush
    elseif action=='feed' then item=Config.Items.food
    elseif action=='water' then item=Config.Items.water end

    if item and Config.Care and Config.Care.requireItems then
        if careInventoryCount(src,item)<1 then
            local label=(Config.Care.labels and Config.Care.labels[action]) or item
            return VORPAdapter.notify(src,('Você precisa de: %s.'):format(label))
        end
        local consume=Config.Care.consume and Config.Care.consume[action]
        if consume and not careInventorySub(src,item,1) then
            return VORPAdapter.notify(src,'Não foi possível consumir o item do inventário.')
        end
    end

    local health,stamina,hunger,thirst,clean=tonumber(h.health),tonumber(h.stamina),tonumber(h.hunger),tonumber(h.thirst),tonumber(h.cleanliness)
    if action=='brush' then clean=LRRP.Clamp(clean+(a.cleanliness or 0),0,100); health=health+(a.health or 0)
    elseif action=='feed' then hunger=LRRP.Clamp(hunger+(a.hunger or 0),0,100); health=health+(a.health or 0)
    elseif action=='water' or action=='river' then thirst=LRRP.Clamp(thirst+(a.thirst or 0),0,100); stamina=stamina+(a.stamina or 0)
    elseif action=='train' then stamina=stamina+(a.stamina or 0) end
    local oldBonding=math.max(1,tonumber(h.bonding) or LRRP.BondingFromXP(h.xp))
    local currentBenefit=Config.BondingBenefits[oldBonding] or Config.BondingBenefits[1] or {}
    local xpGain=math.max(0,math.floor(((tonumber(a.xp) or 0)*(tonumber(currentBenefit.actionXpMultiplier) or 1.0))+0.5))
    local xp=(tonumber(h.xp) or 0)+xpGain
    local bonding=LRRP.BondingFromXP(xp)
    local training=(tonumber(h.training) or 0)+(action=='train' and 1 or 0)

    local benefit=Config.BondingBenefits[bonding] or Config.BondingBenefits[1] or {}
    local hb=math.min(Config.StatEvolution.maxBonus,(tonumber(benefit.healthBonus) or 0)+training*Config.StatEvolution.healthPerTraining)
    local sb=math.min(Config.StatEvolution.maxBonus,(tonumber(benefit.staminaBonus) or 0)+training*Config.StatEvolution.staminaPerTraining)

    health=LRRP.Clamp(health,0,100+hb)
    stamina=LRRP.Clamp(stamina,0,100+sb)

    DB.update('UPDATE lrrp_horses SET health=?,stamina=?,hunger=?,thirst=?,cleanliness=?,xp=?,bonding=?,training=?,updated_at=CURRENT_TIMESTAMP WHERE id=?',{health,stamina,hunger,thirst,clean,xp,bonding,training,h.id})
    TriggerClientEvent('lrrp_stables:actionApplied',src,action,{health=health,stamina=stamina,hunger=hunger,thirst=thirst,cleanliness=clean,xp=xp,bonding=bonding,training=training})

    if bonding>oldBonding then
        TriggerClientEvent('lrrp_stables:bondingLevelUp',src,{
            level=bonding,
            label=tostring(benefit.label or ''),
            healthBonus=tonumber(benefit.healthBonus) or 0,
            staminaBonus=tonumber(benefit.staminaBonus) or 0,
            whistleDistance=tonumber(benefit.whistleDistance) or 35
        })
    end
    sendUIData(src)
end)

RegisterNetEvent('lrrp_stables:openBag',function(horseId)
    local src=source
    if not LRRPGuard.allow(src,'open_bag',Config.Performance.bagOpenMinMs) then return end
    local h=getOwned(src,tonumber(horseId))
    if not h then
        print(('[estabulo_VT] ALFORJE NEGADO | src=%s cavalo=%s sem propriedade'):format(
            tostring(src),tostring(horseId)
        ))
        return VORPAdapter.notify(src,'Este cavalo não pertence ao seu personagem.')
    end

    local _,cid=owner(src)
    local ok,msg=HorseInventory.open(src,tonumber(horseId),cid,h.name)

    if not ok then
        VORPAdapter.notify(src,msg)
    end
end)

RegisterNetEvent('lrrp_stables:buyAccessory',function(category,component)
    local src=source; local id,cid=owner(src); if not id then return end
    if not LRRPGuard.allow(src,'buy_accessory',Config.Performance.economyActionMinMs) then return end
    category=tostring(category or ''); component=tostring(component or ''):upper()
    local item=LRRPAccessoryFind(category,component)
    if not item then return VORPAdapter.notify(src,'Acessório inválido.') end
    local exists=DB.single('SELECT id FROM lrrp_stable_accessories WHERE identifier=? AND charidentifier=? AND category=? AND component_hash=? LIMIT 1',{id,cid,category,component})
    if exists then return VORPAdapter.notify(src,'Você já possui este acessório.') end
    local currency=tonumber(item.currency) or 0; local price=tonumber(item.price) or 0
    if not VORPAdapter.removeCurrency(src,currency,price) then return VORPAdapter.notify(src,currency==1 and 'Ouro insuficiente.' or 'Dinheiro insuficiente.') end
    DB.insert('INSERT INTO lrrp_stable_accessories(identifier,charidentifier,category,component_hash,price_paid,currency) VALUES(?,?,?,?,?,?)',{id,cid,category,component,price,currency})
    VORPAdapter.notify(src,'Acessório comprado com sucesso.'); sendUIData(src)
end)

RegisterNetEvent('lrrp_stables:setAccessory',function(horseId,key,component)
    local src=source
    local h=getOwned(src,tonumber(horseId))
    if not h then return VORPAdapter.notify(src,'Cavalo não encontrado.') end

    key=tostring(key or '')
    component=tostring(component or '0'):upper()

    local validKey=false
    for _,cat in ipairs(LRRPAccessoryCategories or {}) do
        if cat.key==key then validKey=true break end
    end
    if not validKey then return VORPAdapter.notify(src,'Categoria de acessório inválida.') end

    if component~='0' then
        if not LRRPAccessoryFind(key,component) then
            return VORPAdapter.notify(src,'Acessório inválido.')
        end
        local id,cid=owner(src)
        local owned=DB.single(
            'SELECT id FROM lrrp_stable_accessories WHERE identifier=? AND charidentifier=? AND category=? AND UPPER(component_hash)=? LIMIT 1',
            {id,cid,key,component}
        )
        if not owned then
            return VORPAdapter.notify(src,'Compre este acessório antes de equipar.')
        end
    end

    local accessories=LRRP.SafeJsonDecode(h.accessories)
    if type(accessories)~='table' then accessories={} end

    if component=='0' then
        accessories[key]=nil
    else
        accessories[key]=component
    end

    local encoded=LRRP.SafeJsonEncode(accessories)
    local changed=DB.update(
        'UPDATE lrrp_horses SET accessories=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND identifier=? AND charidentifier=?',
        {encoded,h.id,h.identifier,h.charidentifier}
    )

    print(('[estabulo_VT] ACESSORIO | cavalo=%s categoria=%s componente=%s alterados=%s json=%s'):format(
        tostring(h.id),key,component,tostring(changed),encoded
    ))

    TriggerClientEvent('lrrp_stables:equipAccessoryClient',src,key,component)
    VORPAdapter.notify(src,component=='0' and 'Acessório removido.' or 'Acessório equipado com sucesso.')
    sendUIData(src)
end)



RegisterNetEvent('lrrp_stables:buyHorseshoe',function(horseId,level)
    local src=source; local h=getOwned(src,tonumber(horseId)); if not h then return end
    if not LRRPGuard.allow(src,'buy_horseshoe',Config.Performance.economyActionMinMs) then return end
    level=tonumber(level) or 0; local selected=nil
    for _,u in ipairs((Config.Horseshoes and Config.Horseshoes.levels) or {}) do if tonumber(u.level)==level then selected=u break end end
    if not selected then return VORPAdapter.notify(src,'Ferradura inválida.') end
    local upgrades=LRRP.SafeJsonDecode(h.upgrades); local current=tonumber(upgrades.horseshoe or 0) or 0
    if current>=level then return VORPAdapter.notify(src,'Este cavalo já possui esta ferradura ou superior.') end
    local shoePrice=tonumber(selected.price) or 0
    if Config.Farrier and Config.Farrier.jobs[VORPAdapter.job(src) or ''] then shoePrice=math.floor(shoePrice*(1-(Config.Farrier.serviceDiscount or 0))) end
    if not VORPAdapter.removeCurrency(src,selected.currency or 0,shoePrice) then
        return VORPAdapter.notify(src,(selected.currency==1 and 'Ouro insuficiente.' or 'Dinheiro insuficiente.'))
    end
    upgrades.horseshoe=level
    DB.update('UPDATE lrrp_horses SET upgrades=?,horseshoe_durability=100,updated_at=CURRENT_TIMESTAMP WHERE id=?',{LRRP.SafeJsonEncode(upgrades),h.id})
    VORPAdapter.notify(src,('Ferradura instalada: %s'):format(selected.label or ('Nível '..level)))
    sendUIData(src)
end)

RegisterNetEvent('lrrp_stables:sell',function(horseId)
    local src=source; local h=getOwned(src,tonumber(horseId)); if not h then return end
    if not LRRPGuard.allow(src,'sell_horse',Config.Performance.economyActionMinMs) then return end
    local isWild=tonumber(h.wild_origin) == 1
    local value
    local currency

    if isWild then
        -- Cavalos domesticados na natureza têm preço fixo de revenda.
        value=tonumber(Config.WildHorseSalePrice) or 12
        currency=0
    else
        value=math.floor((tonumber(h.price) or 0)*Config.SalePercent)
        currency=tonumber(h.purchase_currency) or 0
    end
    HorseInventory.delete(h.id)
    DB.update('DELETE FROM lrrp_horses WHERE id=?',{h.id})
    VORPAdapter.addCurrency(src,currency,value)
    VORPAdapter.notify(src,('Cavalo vendido por %s%s.'):format(currency==1 and '' or '$',tostring(value)))
    print(('[estabulo_VT] VENDA OK | src=%s cavalo=%s valor=%s moeda=%s'):format(
        tostring(src),tostring(h.id),tostring(value),tostring(currency)
    ))
    local id,cid=owner(src); local p=DB.single('SELECT id FROM lrrp_horses WHERE identifier=? AND charidentifier=? ORDER BY id ASC LIMIT 1',{id,cid})
    if p then DB.update('UPDATE lrrp_horses SET is_primary=1 WHERE id=?',{p.id}) end
    TriggerClientEvent('lrrp_stables:forceDismiss',src,h.id); sendUIData(src)
end)

local PendingHorseTransfers = {}
local TRANSFER_TIMEOUT_MS = 30000

RegisterNetEvent('lrrp_stables:transfer',function(horseId,target)
    local src=source
    if not LRRPGuard.allow(src,'transfer_horse',Config.Performance.economyActionMinMs) then return end
    target=tonumber(target)

    if not target or target==src or GetPlayerPing(target)<=0 then
        return VORPAdapter.notify(src,'Jogador de destino inválido ou offline.')
    end

    local h=getOwned(src,tonumber(horseId))
    if not h then
        return VORPAdapter.notify(src,'Este cavalo não pertence ao seu personagem.')
    end

    local tid,tcid=owner(target)
    if not tid or not tcid then
        return VORPAdapter.notify(src,'Não foi possível identificar o personagem de destino.')
    end

    local n=DB.single('SELECT COUNT(*) AS total FROM lrrp_horses WHERE identifier=? AND charidentifier=?',{tid,tcid})
    if (n and tonumber(n.total) or 0)>=maxHorses(target) then
        return VORPAdapter.notify(src,'O jogador de destino atingiu o limite de cavalos.')
    end

    local token=('%s:%s:%s'):format(src,target,GetGameTimer())
    PendingHorseTransfers[token]={
        from=src,
        to=target,
        horseId=tonumber(h.id),
        horseName=tostring(h.name or ('Cavalo #'..tostring(h.id))),
        expires=GetGameTimer()+TRANSFER_TIMEOUT_MS
    }

    TriggerClientEvent('lrrp_stables:transferOffer',target,{
        token=token,
        from=src,
        horseId=h.id,
        horseName=h.name,
        timeout=30
    })

    VORPAdapter.notify(src,('Oferta enviada. %s precisa aceitar em até 30 segundos.'):format(tostring(h.name)))
    print(('[estabulo_VT] TRANSFERENCIA OFERTA | de=%s para=%s cavalo=%s token=%s'):format(
        tostring(src),tostring(target),tostring(h.id),token
    ))
end)

RegisterNetEvent('lrrp_stables:transferReply',function(token,accepted)
    local target=source
    token=tostring(token or '')
    local p=PendingHorseTransfers[token]
    if not p or p.to~=target then return end

    PendingHorseTransfers[token]=nil

    if GetGameTimer()>p.expires then
        VORPAdapter.notify(target,'A oferta de transferência expirou.')
        if GetPlayerPing(p.from)>0 then VORPAdapter.notify(p.from,'A oferta de transferência expirou.') end
        return
    end

    if not accepted then
        VORPAdapter.notify(target,'Transferência recusada.')
        if GetPlayerPing(p.from)>0 then VORPAdapter.notify(p.from,'O jogador recusou a transferência.') end
        return
    end

    if GetPlayerPing(p.from)<=0 then
        return VORPAdapter.notify(target,'O dono do cavalo não está mais online.')
    end

    -- Revalida propriedade e limite no momento da aceitação.
    local h=getOwned(p.from,p.horseId)
    if not h then
        return VORPAdapter.notify(target,'O cavalo não está mais disponível.')
    end

    local tid,tcid=owner(target)
    if not tid or not tcid then return end

    local n=DB.single('SELECT COUNT(*) AS total FROM lrrp_horses WHERE identifier=? AND charidentifier=?',{tid,tcid})
    if (n and tonumber(n.total) or 0)>=maxHorses(target) then
        VORPAdapter.notify(target,'Você atingiu o limite de cavalos.')
        return VORPAdapter.notify(p.from,'O jogador de destino atingiu o limite de cavalos.')
    end

    local _,oldcid=owner(p.from)
    DB.update('UPDATE lrrp_horses SET identifier=?,charidentifier=?,is_primary=0 WHERE id=?',{
        tid,tcid,h.id
    })

    -- O alforje acompanha o ID do cavalo, portanto o conteúdo é preservado.
    HorseInventory.transfer(h.id,oldcid,tcid,h.name)

    -- Se o cavalo transferido era o principal, escolhe outro para o antigo dono.
    local oid,ocid=owner(p.from)
    local current=DB.single('SELECT id FROM lrrp_horses WHERE identifier=? AND charidentifier=? AND is_primary=1 LIMIT 1',{oid,ocid})
    if not current then
        local replacement=DB.single('SELECT id FROM lrrp_horses WHERE identifier=? AND charidentifier=? ORDER BY id ASC LIMIT 1',{oid,ocid})
        if replacement then DB.update('UPDATE lrrp_horses SET is_primary=1 WHERE id=?',{replacement.id}) end
    end

    VORPAdapter.notify(p.from,('%s foi transferido com sucesso.'):format(tostring(h.name)))
    VORPAdapter.notify(target,('Você recebeu o cavalo %s.'):format(tostring(h.name)))
    TriggerClientEvent('lrrp_stables:forceDismiss',p.from,h.id)
    sendUIData(p.from)
    sendUIData(target)

    print(('[estabulo_VT] TRANSFERENCIA OK | de=%s para=%s cavalo=%s'):format(
        tostring(p.from),tostring(target),tostring(h.id)
    ))
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now=GetGameTimer()
        for token,p in pairs(PendingHorseTransfers) do
            if now>p.expires then
                PendingHorseTransfers[token]=nil
                if GetPlayerPing(p.from)>0 then
                    VORPAdapter.notify(p.from,'A oferta de transferência expirou.')
                end
                if GetPlayerPing(p.to)>0 then
                    VORPAdapter.notify(p.to,'A oferta de transferência expirou.')
                end
            end
        end
    end
end)

-- Diagnóstico de economia para instalação/compatibilidade VORP.
RegisterCommand('estabulosaldo', function(source)
    if source <= 0 then return end
    local money = VORPAdapter.balance(source, 0)
    local gold = VORPAdapter.balance(source, 1)
    VORPAdapter.notify(source, ('Saldo detectado pelo Estábulo: $ %.2f | Ouro %.2f'):format(money, gold))
    print(('[estabulo_VT] saldo source=%s money=%s gold=%s'):format(source, tostring(money), tostring(gold)))
end, false)
