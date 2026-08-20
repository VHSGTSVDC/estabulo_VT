local function ident(src)
    local id,cid,c=VORPAdapter.identity(src)
    return id,cid,c
end
local function decode(v) return LRRP.SafeJsonDecode(v) end
local function encode(v) return LRRP.SafeJsonEncode(v or {}) end
local function nowPlusSeconds(sec) return os.date('%Y-%m-%d %H:%M:%S',os.time()+math.floor(tonumber(sec) or 0)) end
local function parseSqlDate(v)
    if not v then return nil end
    local y,m,d,H,M,S=tostring(v):match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
    if not y then return nil end
    return os.time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=tonumber(H),min=tonumber(M),sec=tonumber(S)})
end
local function future(v) local t=parseSqlDate(v); return t and t>os.time() or false end
local function mine(src,horseId)
    local id,cid=ident(src); if not id then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{tonumber(horseId),id,cid})
end
local function invReady() return GetResourceState('vorp_inventory')=='started' end
local function itemCount(src,item)
    if not invReady() then return 0 end
    local ok,res=pcall(function() return exports.vorp_inventory:getItem(src,item) end)
    if not ok or not res then return 0 end
    return tonumber(res.count) or 0
end
local function consume(src,item,amount)
    amount=math.max(1,math.floor(tonumber(amount) or 1))
    if itemCount(src,item)<amount then return false end
    local ok,res=pcall(function() return exports.vorp_inventory:subItem(src,item,amount) end)
    return ok and res~=false
end
local function addItem(src,item,amount,metadata)
    if not invReady() then return false end
    local ok,res=pcall(function() return exports.vorp_inventory:addItem(src,item,amount or 1,metadata or {}) end)
    return ok and res~=false
end

LRRPV7ConsumeProfessionalItem=function(src,kind)
    local def=Config.ProfessionalItems and Config.ProfessionalItems[kind]
    if not def or not def.item then return true end
    if not consume(src,def.item,def.amount or 1) then
        VORPAdapter.notify(src,('Você precisa de %dx %s para realizar este serviço.'):format(def.amount or 1,def.item))
        return false
    end
    return true
end

local function weightedRarity()
    local total=0; for _,r in ipairs(Config.GeneticsV7.rarity or {}) do total=total+(tonumber(r.weight) or 0) end
    local pick=math.random()*math.max(total,1); local acc=0
    for _,r in ipairs(Config.GeneticsV7.rarity or {}) do acc=acc+(tonumber(r.weight) or 0); if pick<=acc then return r end end
    return (Config.GeneticsV7.rarity or {})[1] or {key='common',label='Comum',bonus=0}
end
local function parentStats(h)
    local g=decode(h.genetics); local base=LRRPHorseStats(LRRPHorseFind(h.model) or h.model) or {}
    return {speed=tonumber(g.speed) or tonumber(base.speed) or 5,acceleration=tonumber(g.acceleration) or tonumber(base.acceleration) or 5,endurance=tonumber(g.endurance) or tonumber(base.endurance) or 5,temperament=tonumber(g.temperament) or tonumber(base.temperament) or 5}
end
local function buildGenetics(mother,father)
    local a,b=parentStats(mother),parentStats(father); local rarity=weightedRarity(); local mutation={}
    local out={rarity=rarity.key}
    for _,k in ipairs({'speed','acceleration','endurance','temperament'}) do
        local n=math.floor(((a[k]+b[k])/2)+0.5)+(tonumber(rarity.bonus) or 0)
        if math.random()<(Config.GeneticsV7.mutationChance or 0) then
            local delta=math.random(0,1)==1 and (Config.GeneticsV7.mutationRange or 1) or -(Config.GeneticsV7.mutationRange or 1)
            n=n+delta; mutation[k]=delta
        end
        out[k]=math.max(1,math.min(10,n))
    end
    return out,mutation,rarity
end

local function ranchData(id,cid)
    return DB.single('SELECT * FROM lrrp_ranches WHERE identifier=? AND charidentifier=?',{id,cid})
end
local function auctionRows()
    local rows=DB.query([[SELECT a.*,h.name,h.model,h.sex,h.rarity,h.genetics FROM lrrp_stable_auctions a JOIN lrrp_horses h ON h.id=a.horse_id WHERE a.status='active' AND a.ends_at>NOW() ORDER BY a.ends_at ASC LIMIT 100]],{}) or {}
    for _,r in ipairs(rows) do r.genetics=decode(r.genetics); r.catalog=LRRPHorseFind(r.model) end
    return rows
end
local function championshipRows()
    return DB.query([[SELECT p.*,h.name,h.model FROM lrrp_stable_championship_points p LEFT JOIN lrrp_horses h ON h.id=p.horse_id WHERE p.season=? ORDER BY p.points DESC,p.wins DESC,p.races ASC LIMIT 50]],{Config.Championship.season}) or {}
end
local function v7Data(src)
    local id,cid=ident(src); if not id then return end

    local pregnancies=DB.query([[
        SELECT p.*,m.name mother_name,f.name father_name
        FROM lrrp_stable_pregnancies p
        LEFT JOIN lrrp_horses m ON m.id=p.mother_id
        LEFT JOIN lrrp_horses f ON f.id=p.father_id
        WHERE p.identifier=? AND p.charidentifier=? AND p.status='pregnant'
        ORDER BY p.finish_at
    ]],{id,cid}) or {}

    local pedigreeRows=DB.query([[
        SELECT h.id,h.name,h.sex,h.birth_at,h.life_stage,h.rarity,h.genetics,h.mutation,
               h.father_id,h.mother_id,h.breeding_cooldown_until,
               f.name AS father_name,m.name AS mother_name
        FROM lrrp_horses h
        LEFT JOIN lrrp_horses f ON f.id=h.father_id
        LEFT JOIN lrrp_horses m ON m.id=h.mother_id
        WHERE h.identifier=? AND h.charidentifier=?
        ORDER BY h.id
    ]],{id,cid}) or {}

    local pedigrees={}
    for _,r in ipairs(pedigreeRows) do
        r.genetics=decode(r.genetics)
        r.mutation=decode(r.mutation)
        pedigrees[tostring(r.id)]=r
    end

    TriggerClientEvent('lrrp_stables:v7DataClient',src,{
        ranch=ranchData(id,cid),
        pregnancies=pregnancies,
        pedigrees=pedigrees,
        breeding={
            fee=Config.Breeding.fee,
            currency=Config.Breeding.currency,
            minBonding=Config.Breeding.minBonding,
            minTraining=Config.Breeding.minTraining,
            gestationHours=Config.Pregnancy.gestationHours,
            growth=Config.Pregnancy.growth
        },
        auctions=auctionRows(),
        championship=championshipRows(),
        season=Config.Championship.season
    })
end
RegisterNetEvent('lrrp_stables:v7Data',function() v7Data(source) end)

RegisterNetEvent('lrrp_stables:createRanch',function(name,coords)
    local src=source; if not Config.Ranch.enabled then return end
    local id,cid=ident(src); if not id then return end
    if ranchData(id,cid) then return VORPAdapter.notify(src,'Você já possui um rancho.') end
    if not VORPAdapter.removeCurrency(src,Config.Ranch.currency,Config.Ranch.creationPrice) then return VORPAdapter.notify(src,'Saldo insuficiente para criar o rancho.') end
    coords=type(coords)=='table' and coords or {}; name=tostring(name or 'Meu Rancho'):sub(1,80)
    DB.insert('INSERT INTO lrrp_ranches(identifier,charidentifier,name,level,capacity,x,y,z) VALUES(?,?,?,1,?,?,?,?)',{id,cid,name,Config.Ranch.baseCapacity,tonumber(coords.x) or 0,tonumber(coords.y) or 0,tonumber(coords.z) or 0})
    VORPAdapter.notify(src,'Rancho criado com sucesso.'); v7Data(src)
end)

RegisterNetEvent('lrrp_stables:upgradeRanch',function()
    local src=source; local id,cid=ident(src); local r=id and ranchData(id,cid) or nil; if not r then return end
    local nextDef=nil; for _,u in ipairs(Config.Ranch.upgrades or {}) do if tonumber(u.level)==tonumber(r.level)+1 then nextDef=u break end end
    if not nextDef then return VORPAdapter.notify(src,'Seu rancho já está no nível máximo.') end
    if not VORPAdapter.removeCurrency(src,Config.Ranch.currency,nextDef.price) then return VORPAdapter.notify(src,'Saldo insuficiente para a melhoria.') end
    DB.update('UPDATE lrrp_ranches SET level=?,capacity=? WHERE id=?',{nextDef.level,nextDef.capacity,r.id}); VORPAdapter.notify(src,nextDef.label..' concluído.'); v7Data(src)
end)

RegisterNetEvent('lrrp_stables:assignRanch',function(horseId)
    local src=source; local id,cid=ident(src); local h=mine(src,horseId); local r=id and ranchData(id,cid) or nil; if not h or not r then return end
    local c=DB.single('SELECT COUNT(*) total FROM lrrp_horses WHERE ranch_id=?',{r.id}); if (tonumber(c and c.total) or 0)>=tonumber(r.capacity) then return VORPAdapter.notify(src,'O rancho atingiu a capacidade máxima.') end
    DB.update('UPDATE lrrp_horses SET ranch_id=? WHERE id=?',{r.id,h.id}); VORPAdapter.notify(src,'Cavalo vinculado ao rancho.'); TriggerClientEvent('lrrp_stables:refreshV6',src); v7Data(src)
end)

local function closeRelative(a,b)
    if not a or not b then return false end

    -- pai/mãe x filho
    if tonumber(a.father_id)==tonumber(b.id) or tonumber(a.mother_id)==tonumber(b.id)
       or tonumber(b.father_id)==tonumber(a.id) or tonumber(b.mother_id)==tonumber(a.id) then
        return true,'Não é permitido cruzar pai/mãe com filho.'
    end

    -- irmãos pelo mesmo pai ou pela mesma mãe
    if a.father_id and b.father_id and tonumber(a.father_id)>0
       and tonumber(a.father_id)==tonumber(b.father_id) then
        return true,'Não é permitido cruzar irmãos do mesmo pai.'
    end

    if a.mother_id and b.mother_id and tonumber(a.mother_id)>0
       and tonumber(a.mother_id)==tonumber(b.mother_id) then
        return true,'Não é permitido cruzar irmãos da mesma mãe.'
    end

    return false,nil
end

RegisterNetEvent('lrrp_stables:removeFromRanch',function(horseId)
    local src=source
    local id,cid=ident(src)
    local h=mine(src,horseId)
    if not id or not h then return end
    DB.update('UPDATE lrrp_horses SET ranch_id=NULL WHERE id=?',{h.id})
    VORPAdapter.notify(src,'Cavalo removido do rancho.')
    TriggerClientEvent('lrrp_stables:refreshV6',src)
    v7Data(src)
end)

RegisterNetEvent('lrrp_stables:startPregnancy',function(motherId,fatherId,foalName)
    local src=source
    if not Config.Pregnancy.enabled then
        return VORPAdapter.notify(src,'O sistema de reprodução está desativado.')
    end

    local id,cid=ident(src)
    local mother=mine(src,motherId)
    local father=mine(src,fatherId)

    if not id or not mother or not father then
        return VORPAdapter.notify(src,'Selecione dois cavalos válidos.')
    end

    if tonumber(mother.id)==tonumber(father.id) then
        return VORPAdapter.notify(src,'Selecione dois cavalos diferentes.')
    end

    if tostring(mother.sex)~='female' or tostring(father.sex)~='male' then
        return VORPAdapter.notify(src,'A criação exige uma fêmea e um macho.')
    end

    if mother.death_state~='alive' or father.death_state~='alive'
       or mother.life_stage~='adult' or father.life_stage~='adult' then
        return VORPAdapter.notify(src,'Somente cavalos adultos e vivos podem reproduzir.')
    end

    local related,reason=closeRelative(mother,father)
    if related then return VORPAdapter.notify(src,reason) end

    local active=DB.single(
        "SELECT id FROM lrrp_stable_pregnancies WHERE mother_id=? AND status='pregnant' LIMIT 1",
        {mother.id}
    )
    if active then
        return VORPAdapter.notify(src,'Esta égua já está em gestação.')
    end

    if future(mother.breeding_cooldown_until) or future(father.breeding_cooldown_until) then
        return VORPAdapter.notify(src,'Um dos cavalos ainda está em descanso reprodutivo.')
    end

    if (tonumber(mother.bonding) or 0)<(tonumber(Config.Breeding.minBonding) or 0)
       or (tonumber(father.bonding) or 0)<(tonumber(Config.Breeding.minBonding) or 0) then
        return VORPAdapter.notify(src,('Bonding mínimo: %s.'):format(tostring(Config.Breeding.minBonding)))
    end

    if (tonumber(mother.training) or 0)<(tonumber(Config.Breeding.minTraining) or 0)
       or (tonumber(father.training) or 0)<(tonumber(Config.Breeding.minTraining) or 0) then
        return VORPAdapter.notify(src,('Treinamento mínimo: %s.'):format(tostring(Config.Breeding.minTraining)))
    end

    foalName=tostring(foalName or 'Potro'):gsub('^%s+',''):gsub('%s+$',''):sub(1,32)
    if #foalName<2 then
        return VORPAdapter.notify(src,'Escolha um nome válido para o futuro potro.')
    end

    -- Cobrança é a última validação antes de criar a gestação.
    if not VORPAdapter.removeCurrency(src,Config.Breeding.currency,Config.Breeding.fee) then
        return VORPAdapter.notify(src,'Saldo insuficiente para a criação.')
    end

    local finish=nowPlusSeconds((Config.Pregnancy.gestationHours or 24)*3600)
    local cooldown=nowPlusSeconds((Config.Breeding.cooldownHours or 48)*3600)

    local pregnancyId=DB.insert([[
        INSERT INTO lrrp_stable_pregnancies
        (identifier,charidentifier,mother_id,father_id,foal_name,finish_at,status)
        VALUES(?,?,?,?,?,?,'pregnant')
    ]],{id,cid,mother.id,father.id,foalName,finish})

    if not pregnancyId then
        VORPAdapter.addCurrency(src,Config.Breeding.currency,Config.Breeding.fee)
        return VORPAdapter.notify(src,'Erro ao registrar gestação. O valor foi devolvido.')
    end

    DB.update(
        'UPDATE lrrp_horses SET breeding_cooldown_until=? WHERE id IN (?,?)',
        {cooldown,mother.id,father.id}
    )

    TriggerClientEvent('lrrp_stables:breedingSceneClient',src,{
        motherModel=mother.model,
        fatherModel=father.model,
        ranchId=mother.ranch_id
    })

    VORPAdapter.notify(src,('Gestação iniciada. Nascimento previsto em %s hora(s).'):format(
        tostring(Config.Pregnancy.gestationHours or 24)
    ))

    print(('[estabulo_VT v1.5.0] GESTACAO INICIADA | src=%s mae=%s pai=%s nome=%s fim=%s'):format(
        tostring(src),tostring(mother.id),tostring(father.id),foalName,finish
    ))

    v7Data(src)
end)

local function processPregnancies()
    local rows=DB.query("SELECT * FROM lrrp_stable_pregnancies WHERE status='pregnant' AND finish_at<=NOW() LIMIT 50",{}) or {}
    for _,p in ipairs(rows) do
        local mother=DB.single('SELECT * FROM lrrp_horses WHERE id=?',{p.mother_id}); local father=DB.single('SELECT * FROM lrrp_horses WHERE id=?',{p.father_id})
        if mother and father then
            local genetics,mutation,rarity=buildGenetics(mother,father); local inherited=(math.random(1,2)==1 and mother or father); local sex=(math.random(1,2)==1 and 'male' or 'female')
            DB.insert([[INSERT INTO lrrp_horses(identifier,charidentifier,name,model,is_primary,price,purchase_currency,health,stamina,hunger,thirst,cleanliness,xp,bonding,training,accessories,weapon_storage,upgrades,sex,birth_at,father_id,mother_id,genetics,health_state,life_stage,rarity,mutation,death_state,ranch_id)
            VALUES(?,?,?,?,0,0,0,?,?,?,?,?,0,0,0,'{}','{}','{}',?,NOW(),?,?,?,'{}','newborn',?,?,'alive',?)]],{p.identifier,p.charidentifier,p.foal_name,inherited.model,Config.Breeding.foalStartHealth,Config.Breeding.foalStartStamina,100,100,100,sex,father.id,mother.id,encode(genetics),rarity.key,encode(mutation),mother.ranch_id})
            DB.update("UPDATE lrrp_stable_pregnancies SET status='born' WHERE id=?",{p.id})
            print(('[estabulo_VT v1.5.0] POTRO NASCEU | gestacao=%s nome=%s mae=%s pai=%s raridade=%s'):format(
                tostring(p.id),tostring(p.foal_name),tostring(mother.id),tostring(father.id),tostring(rarity.key)
            ))
        else DB.update("UPDATE lrrp_stable_pregnancies SET status='failed' WHERE id=?",{p.id}) end
    end
end
local function processGrowth()
    local rows=DB.query("SELECT id,birth_at,life_stage FROM lrrp_horses WHERE life_stage IN ('newborn','foal','juvenile') AND death_state='alive'",{}) or {}
    for _,h in ipairs(rows) do
        local born=parseSqlDate(h.birth_at); if born then
            local age=(os.time()-born)/3600; local stage=h.life_stage
            if age>=(Config.Pregnancy.growth.adultHours or 72) then stage='adult'
            elseif age>=(Config.Pregnancy.growth.juvenileHours or 48) then stage='juvenile'
            elseif age>=(Config.Pregnancy.growth.foalHours or 24) then stage='foal'
            else stage='newborn' end
            if stage~=h.life_stage then DB.update('UPDATE lrrp_horses SET life_stage=? WHERE id=?',{stage,h.id}) end
        end
    end
end

RegisterNetEvent('lrrp_stables:pedigreeCertificate',function(horseId)
    local src=source; local h=mine(src,horseId); if not h then return end
    if not VORPAdapter.removeCurrency(src,Config.Pedigree.currency,Config.Pedigree.fee) then return VORPAdapter.notify(src,'Saldo insuficiente para emitir o pedigree.') end
    local father=h.father_id and DB.single('SELECT name FROM lrrp_horses WHERE id=?',{h.father_id}) or nil; local mother=h.mother_id and DB.single('SELECT name FROM lrrp_horses WHERE id=?',{h.mother_id}) or nil
    local metadata={horse_id=h.id,horse_name=h.name,model=h.model,sex=h.sex,rarity=h.rarity or 'common',father=father and father.name or 'Desconhecido',mother=mother and mother.name or 'Desconhecida',genetics=decode(h.genetics),issued_at=os.date('%Y-%m-%d %H:%M:%S')}
    if not addItem(src,Config.Pedigree.item,1,metadata) then VORPAdapter.addCurrency(src,Config.Pedigree.currency,Config.Pedigree.fee); return VORPAdapter.notify(src,'Não foi possível adicionar o certificado. Cadastre o item '..Config.Pedigree.item..' no VORP Inventory.') end
    VORPAdapter.notify(src,'Certificado de pedigree emitido no inventário.')
end)

RegisterNetEvent('lrrp_stables:insureHorse',function(horseId)
    local src=source; local h=mine(src,horseId); if not h then return end
    if not VORPAdapter.removeCurrency(src,Config.Insurance.currency,Config.Insurance.price) then return VORPAdapter.notify(src,'Saldo insuficiente para contratar o seguro.') end
    local untilAt=nowPlusSeconds((Config.Insurance.durationHours or 168)*3600); DB.update('UPDATE lrrp_horses SET insurance_until=? WHERE id=?',{untilAt,h.id}); VORPAdapter.notify(src,'Seguro contratado por 7 dias.'); TriggerClientEvent('lrrp_stables:refreshV6',src)
end)
RegisterNetEvent('lrrp_stables:claimInsurance',function(horseId)
    local src=source
    local h=mine(src,horseId)
    if not h or h.death_state~='claimable' or not future(h.insurance_until) then
        return VORPAdapter.notify(src,'Não há sinistro coberto para este cavalo.')
    end
    if not VORPAdapter.removeCurrency(src,Config.Insurance.currency,Config.Insurance.deductible) then
        return VORPAdapter.notify(src,'Saldo insuficiente para a franquia.')
    end
    local changed=DB.update([[
        UPDATE lrrp_horses SET death_state='alive',life_stage='adult',health=?,stamina=?,
        insurance_until=NULL,critical_until=NULL,death_confirmations=0,health_state='{}'
        WHERE id=? AND death_state='claimable'
    ]],{Config.Insurance.reviveHealth,Config.Insurance.reviveStamina,h.id})
    if not changed or tonumber(changed)==0 then
        VORPAdapter.addCurrency(src,Config.Insurance.currency,Config.Insurance.deductible)
        return VORPAdapter.notify(src,'O sinistro já foi processado. A franquia foi devolvida.')
    end
    VORPAdapter.notify(src,'🛡️ Seguro acionado. O cavalo foi recuperado.')
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)
-- v2.4.0: morte instantânea removida.
-- O fluxo seguro agora é controlado por server/death_v24.lua.

RegisterNetEvent('lrrp_stables:createAuction',function(horseId,startPrice,currency,durationMinutes)
    local src=source; if not Config.Auction.enabled then return end
    local id,cid=ident(src); local h=mine(src,horseId); if not id or not h then return end
    if h.death_state~='alive' then return VORPAdapter.notify(src,'Cavalo indisponível para leilão.') end
    startPrice=math.max(Config.Market.minPrice,math.floor(tonumber(startPrice) or 0)); currency=tonumber(currency)==1 and 1 or 0
    durationMinutes=math.max(Config.Auction.minDurationMinutes,math.min(Config.Auction.maxDurationMinutes,math.floor(tonumber(durationMinutes) or Config.Auction.defaultDurationMinutes)))
    if not VORPAdapter.removeCurrency(src,Config.Auction.currency,Config.Auction.listingFee) then return VORPAdapter.notify(src,'Saldo insuficiente para a taxa do leilão.') end
    local active=DB.single("SELECT id FROM lrrp_stable_auctions WHERE horse_id=? AND status='active'",{h.id}); if active then return VORPAdapter.notify(src,'Este cavalo já está em leilão.') end
    DB.update('DELETE FROM lrrp_stable_market WHERE horse_id=?',{h.id})
    DB.insert("INSERT INTO lrrp_stable_auctions(horse_id,seller_identifier,seller_charidentifier,start_price,currency,current_bid,ends_at,status) VALUES(?,?,?,?,?,0,?,'active')",{h.id,id,cid,startPrice,currency,nowPlusSeconds(durationMinutes*60)})
    VORPAdapter.notify(src,'Cavalo enviado ao leilão.'); v7Data(src)
end)

RegisterNetEvent('lrrp_stables:bidAuction',function(auctionId,bid)
    local src=source; local id,cid=ident(src); if not id then return end
    local a=DB.single("SELECT * FROM lrrp_stable_auctions WHERE id=? AND status='active' AND ends_at>NOW()",{tonumber(auctionId)}); if not a then return VORPAdapter.notify(src,'Leilão encerrado ou inexistente.') end
    if a.seller_identifier==id and tonumber(a.seller_charidentifier)==cid then return VORPAdapter.notify(src,'Você não pode dar lance no próprio cavalo.') end
    local minimum=math.max(tonumber(a.start_price) or 0,(tonumber(a.current_bid) or 0)+(Config.Auction.minimumIncrement or 1)); bid=math.floor(tonumber(bid) or 0); if bid<minimum then return VORPAdapter.notify(src,('Lance mínimo: %d'):format(minimum)) end
    local ownCurrent=a.bidder_identifier==id and tonumber(a.bidder_charidentifier)==cid; local charge=ownCurrent and (bid-(tonumber(a.current_bid) or 0)) or bid
    if not VORPAdapter.removeCurrency(src,tonumber(a.currency) or 0,charge) then return VORPAdapter.notify(src,'Saldo insuficiente para o lance.') end
    local changed=DB.update("UPDATE lrrp_stable_auctions SET current_bid=?,bidder_identifier=?,bidder_charidentifier=? WHERE id=? AND status='active' AND current_bid<?",{bid,id,cid,a.id,bid})
    if not changed or changed<1 then VORPAdapter.addCurrency(src,a.currency,charge); return VORPAdapter.notify(src,'Outro lance foi registrado antes do seu. Tente novamente.') end
    if a.bidder_identifier and not ownCurrent then DB.insert('INSERT INTO lrrp_stable_payouts(identifier,charidentifier,amount,currency,reason) VALUES(?,?,?,?,?)',{a.bidder_identifier,a.bidder_charidentifier,a.current_bid,a.currency,'Reembolso de lance superado'}) end
    VORPAdapter.notify(src,'Lance registrado.'); v7Data(src)
end)

local function settleAuctions()
    local rows=DB.query("SELECT * FROM lrrp_stable_auctions WHERE status='active' AND ends_at<=NOW() LIMIT 50",{}) or {}
    for _,a in ipairs(rows) do
        if a.bidder_identifier then
            local h=DB.single('SELECT * FROM lrrp_horses WHERE id=?',{a.horse_id})
            if h then
                DB.update('UPDATE lrrp_horses SET identifier=?,charidentifier=?,is_primary=0,ranch_id=NULL WHERE id=?',{a.bidder_identifier,a.bidder_charidentifier,h.id}); HorseInventory.transfer(h.id,a.seller_charidentifier,a.bidder_charidentifier,h.name)
                DB.insert('INSERT INTO lrrp_stable_payouts(identifier,charidentifier,amount,currency,reason) VALUES(?,?,?,?,?)',{a.seller_identifier,a.seller_charidentifier,a.current_bid,a.currency,'Venda em leilão: '..tostring(h.name)})
            end
            DB.update("UPDATE lrrp_stable_auctions SET status='sold' WHERE id=?",{a.id})
        else DB.update("UPDATE lrrp_stable_auctions SET status='expired' WHERE id=?",{a.id}) end
    end
end

AddEventHandler('lrrp_stables:v7RaceFinished',function(src,trackKey,horseId,timeMs)
    if not Config.Championship.enabled then return end
    local id,cid=ident(src); if not id then return end
    local posRow=DB.single('SELECT COUNT(*)+1 pos FROM lrrp_stable_race_results WHERE track_key=? AND time_ms<?',{trackKey,timeMs}); local pos=tonumber(posRow and posRow.pos) or 99
    local pts=pos==1 and Config.Championship.points.first or pos==2 and Config.Championship.points.second or pos==3 and Config.Championship.points.third or Config.Championship.points.finish
    DB.insert([[INSERT INTO lrrp_stable_championship_points(season,identifier,charidentifier,horse_id,points,wins,races) VALUES(?,?,?,?,?,?,1)
      ON DUPLICATE KEY UPDATE points=points+VALUES(points),wins=wins+VALUES(wins),races=races+1]],{Config.Championship.season,id,cid,horseId,pts,pos==1 and 1 or 0})
    v7Data(src)
end)

RegisterCommand('lrrp_finalizartemporada',function(src)
    if src~=0 then return end
    local season=Config.Championship.season; local done=DB.single('SELECT finalized_at FROM lrrp_stable_seasons WHERE season=?',{season}); if done and done.finalized_at then print('[LRRP_Stables] temporada já finalizada: '..season); return end
    local top=DB.query('SELECT * FROM lrrp_stable_championship_points WHERE season=? ORDER BY points DESC,wins DESC LIMIT 3',{season}) or {}
    for i,row in ipairs(top) do local reward=Config.Championship.podiumRewards[i] or 0; if reward>0 then DB.insert('INSERT INTO lrrp_stable_payouts(identifier,charidentifier,amount,currency,reason) VALUES(?,?,?,?,?)',{row.identifier,row.charidentifier,reward,Config.Championship.currency,'Premiação '..season..' - '..i..'º lugar'}) end end
    DB.insert('INSERT INTO lrrp_stable_seasons(season,finalized_at) VALUES(?,NOW()) ON DUPLICATE KEY UPDATE finalized_at=NOW()',{season}); print('[LRRP_Stables] temporada finalizada: '..season)
end,true)

CreateThread(function()
    Wait(5000)
    while true do processPregnancies(); processGrowth(); settleAuctions(); Wait(60000) end
end)
