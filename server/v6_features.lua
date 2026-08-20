local ActiveRaces={}

local function ident(src)
    local id,cid,c=VORPAdapter.identity(src)
    return id,cid,c
end
local function mine(src,horseId)
    local id,cid=ident(src); if not id then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{tonumber(horseId),id,cid})
end
local function decode(v) return LRRP.SafeJsonDecode(v) end
local function nowPlusHours(hours)
    return os.date('%Y-%m-%d %H:%M:%S',os.time()+math.floor((tonumber(hours) or 0)*3600))
end
local function isFuture(sqlDate)
    if not sqlDate then return false end
    local y,m,d,H,M,S=tostring(sqlDate):match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
    if not y then return false end
    return os.time({year=y,month=m,day=d,hour=H,min=M,sec=S})>os.time()
end
local function horsePublic(h)
    if not h then return nil end
    h.genetics=decode(h.genetics); h.health_state=decode(h.health_state); h.upgrades=decode(h.upgrades); h.accessories=decode(h.accessories)
    h.catalog=LRRPHorseFind(h.model); h.breed_stats=LRRPHorseStats(h.catalog or h.model)
    return h
end
local function getMarket()
    local rows=DB.query([[SELECT m.id AS listing_id,m.price AS listing_price,m.currency AS listing_currency,m.created_at AS listed_at,h.*
        FROM lrrp_stable_market m JOIN lrrp_horses h ON h.id=m.horse_id ORDER BY m.created_at DESC LIMIT 100]],{}) or {}
    for i=1,#rows do rows[i]=horsePublic(rows[i]) end
    return rows
end
local function getRankings()
    local out={}
    for _,track in ipairs((Config.Racing and Config.Racing.tracks) or {}) do
        out[track.key]=DB.query([[SELECT r.time_ms,r.horse_id,r.created_at,h.name,h.model FROM lrrp_stable_race_results r
            LEFT JOIN lrrp_horses h ON h.id=r.horse_id WHERE r.track_key=? ORDER BY r.time_ms ASC LIMIT 10]],{track.key}) or {}
    end
    return out
end
local function claimPayouts(src)
    local id,cid=ident(src); if not id then return end
    local rows=DB.query('SELECT id,amount,currency FROM lrrp_stable_payouts WHERE identifier=? AND charidentifier=?',{id,cid}) or {}
    for _,p in ipairs(rows) do
        VORPAdapter.addCurrency(src,tonumber(p.currency) or 0,tonumber(p.amount) or 0)
        DB.update('DELETE FROM lrrp_stable_payouts WHERE id=?',{p.id})
    end
    if #rows>0 then VORPAdapter.notify(src,('Você recebeu %d pagamento(s) pendente(s) do mercado.'):format(#rows)) end
end


local function evaluateHealth(h)
    local state=decode(h.health_state)
    local changed=false
    if tonumber(h.hunger or 100)<20 and not state.disease then state.disease='colic'; changed=true end
    if tonumber(h.thirst or 100)<20 and not state.disease then state.disease='fever'; changed=true end
    if tonumber(h.health or 100)<35 and not state.injury then state.injury='light'; changed=true end
    -- v0.7 controla as fases de crescimento (newborn/foal/juvenile/adult) em server/v7_features.lua
    if changed then DB.update('UPDATE lrrp_horses SET health_state=? WHERE id=?',{LRRP.SafeJsonEncode(state),h.id}) end
    h.health_state=state
    return h
end

RegisterNetEvent('lrrp_stables:startRace',function(trackKey,horseId)
    local src=source; local h=mine(src,horseId); if not h then return end
    local track=nil; for _,t in ipairs(Config.Racing.tracks or {}) do if t.key==trackKey then track=t break end end
    if not track then return end
    if (Config.Racing.entryFee or 0)>0 and not VORPAdapter.removeCurrency(src,Config.Racing.currency,Config.Racing.entryFee) then return VORPAdapter.notify(src,'Saldo insuficiente para a inscrição.') end
    ActiveRaces[src]={trackKey=trackKey,horseId=h.id,started=GetGameTimer()}
    TriggerClientEvent('lrrp_stables:startRaceClient',src,trackKey,h.id)
end)

RegisterNetEvent('lrrp_stables:v6Data',function()
    local src=source; claimPayouts(src)
    local id,cid=ident(src); local healthRows=DB.query('SELECT * FROM lrrp_horses WHERE identifier=? AND charidentifier=?',{id,cid}) or {}; for _,h in ipairs(healthRows) do evaluateHealth(h) end
    TriggerClientEvent('lrrp_stables:v6DataClient',src,{market=getMarket(),rankings=getRankings(),tracks=(Config.Racing and Config.Racing.tracks) or {}})
end)

RegisterNetEvent('lrrp_stables:setSex',function(horseId,sex)
    local src=source; local h=mine(src,horseId); if not h then return end
    sex=tostring(sex or ''):lower(); if sex~='male' and sex~='female' then return end
    DB.update('UPDATE lrrp_horses SET sex=? WHERE id=?',{sex,h.id})
    VORPAdapter.notify(src,sex=='male' and 'Sexo definido: macho.' or 'Sexo definido: fêmea.')
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

RegisterNetEvent('lrrp_stables:breed',function(motherId,fatherId,foalName)
    -- v1.5.0: o sistema antigo de nascimento imediato foi desativado.
    -- Toda reprodução passa pela gestação persistente do v7.
    local src=source
    TriggerClientEvent('lrrp_stables:notify',src,'Use a aba Criação para iniciar uma gestação.')
end)

RegisterNetEvent('lrrp_stables:treatHorse',function(horseId)
    local src=source
    local h=mine(src,horseId)
    if not h then return end

    local state=decode(h.health_state)
    if not next(state) then
        return VORPAdapter.notify(src,'Este cavalo não possui problemas de saúde registrados.')
    end

    if state.treated and state.recovery_until then
        return VORPAdapter.notify(src,('O cavalo já está em recuperação até %s.'):format(tostring(state.recovery_until)))
    end

    local job=VORPAdapter.job(src) or ''
    local price=Config.HealthSystem.treatmentPrice
    if Config.HealthSystem.vetJobs[job] then price=0 end

    if price>0 and not VORPAdapter.removeCurrency(src,Config.HealthSystem.currency,price) then
        return VORPAdapter.notify(src,'Dinheiro insuficiente para o veterinário.')
    end

    local ok=false
    if type(LRRPStartRecoveryV23)=='function' then
        local success,result=pcall(LRRPStartRecoveryV23,src,h.id)
        ok=success and result~=false
    end

    if not ok then
        if price>0 then VORPAdapter.addCurrency(src,Config.HealthSystem.currency,price) end
        return VORPAdapter.notify(src,'Não foi possível iniciar a recuperação. O pagamento foi devolvido.')
    end

    VORPAdapter.notify(src,'🩺 Tratamento concluído. O cavalo entrou em período de recuperação.')
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

RegisterNetEvent('lrrp_stables:listMarket',function(horseId,price,currency)
    local src=source; if not Config.Market.enabled then return end
    local h=mine(src,horseId); if not h then return end
    price=math.floor(tonumber(price) or 0); currency=tonumber(currency)==1 and 1 or 0
    if price<Config.Market.minPrice or price>Config.Market.maxPrice then return VORPAdapter.notify(src,'Preço fora do limite permitido.') end
    local fee=math.floor(price*(Config.Market.listingFeePercent or 0))
    if fee>0 and not VORPAdapter.removeCurrency(src,currency,fee) then return VORPAdapter.notify(src,'Saldo insuficiente para a taxa de anúncio.') end
    local id,cid=ident(src)
    DB.insert('INSERT INTO lrrp_stable_market(horse_id,seller_identifier,seller_charidentifier,price,currency) VALUES(?,?,?,?,?) ON DUPLICATE KEY UPDATE price=VALUES(price),currency=VALUES(currency)',{h.id,id,cid,price,currency})
    VORPAdapter.notify(src,'Cavalo anunciado no mercado.')
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

RegisterNetEvent('lrrp_stables:cancelMarket',function(horseId)
    local src=source; local id,cid=ident(src)
    DB.update('DELETE FROM lrrp_stable_market WHERE horse_id=? AND seller_identifier=? AND seller_charidentifier=?',{tonumber(horseId),id,cid})
    VORPAdapter.notify(src,'Anúncio removido.')
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

RegisterNetEvent('lrrp_stables:buyMarket',function(listingId)
    local src=source; local bid,bcid=ident(src); if not bid then return end
    local listing=DB.single([[SELECT m.*,h.name FROM lrrp_stable_market m JOIN lrrp_horses h ON h.id=m.horse_id WHERE m.id=?]],{tonumber(listingId)})
    if not listing then return VORPAdapter.notify(src,'Este anúncio não está mais disponível.') end
    if listing.seller_identifier==bid and tonumber(listing.seller_charidentifier)==bcid then return VORPAdapter.notify(src,'Você não pode comprar seu próprio cavalo.') end
    local count=DB.single('SELECT COUNT(*) AS total FROM lrrp_horses WHERE identifier=? AND charidentifier=?',{bid,bcid})
    local max=VORPAdapter.isTrainer(src) and Config.TrainerMaxHorses or Config.MaxHorses
    if (tonumber(count and count.total) or 0)>=max then return VORPAdapter.notify(src,'Você atingiu o limite de cavalos.') end
    if not VORPAdapter.removeCurrency(src,tonumber(listing.currency) or 0,tonumber(listing.price) or 0) then return VORPAdapter.notify(src,'Saldo insuficiente.') end
    DB.update('UPDATE lrrp_horses SET identifier=?,charidentifier=?,is_primary=0 WHERE id=?',{bid,bcid,listing.horse_id})
    HorseInventory.transfer(listing.horse_id,tonumber(listing.seller_charidentifier),bcid,listing.name)
    DB.update('DELETE FROM lrrp_stable_market WHERE id=?',{listing.id})
    DB.insert('INSERT INTO lrrp_stable_payouts(identifier,charidentifier,amount,currency,reason) VALUES(?,?,?,?,?)',{listing.seller_identifier,listing.seller_charidentifier,listing.price,listing.currency,'Venda de '..tostring(listing.name)})
    VORPAdapter.notify(src,'Cavalo comprado no mercado.')
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

RegisterNetEvent('lrrp_stables:raceResult',function(trackKey,horseId,timeMs)
    local src=source; local active=ActiveRaces[src]; local h=mine(src,horseId); if not h or not active then return end
    if active.trackKey~=trackKey or tonumber(active.horseId)~=tonumber(horseId) then ActiveRaces[src]=nil; return end
    local serverElapsed=GetGameTimer()-active.started; ActiveRaces[src]=nil
    local track=nil; for _,t in ipairs(Config.Racing.tracks or {}) do if t.key==trackKey then track=t break end end
    timeMs=math.floor(tonumber(timeMs) or 0); if not track or timeMs<3000 or timeMs>3600000 then return end
    if math.abs(serverElapsed-timeMs)>2500 then return VORPAdapter.notify(src,'Tempo da corrida rejeitado pela validação do servidor.') end
    local id,cid=ident(src)
    DB.insert('INSERT INTO lrrp_stable_race_results(track_key,horse_id,identifier,charidentifier,time_ms) VALUES(?,?,?,?,?)',{trackKey,h.id,id,cid,timeMs})
    TriggerEvent('lrrp_stables:v7RaceFinished',src,trackKey,h.id,timeMs)
    local best=DB.single('SELECT MIN(time_ms) AS best FROM lrrp_stable_race_results WHERE track_key=?',{trackKey})
    local reward=(best and tonumber(best.best)==timeMs) and tonumber(track.reward or 0) or 0
    if reward>0 then VORPAdapter.addCurrency(src,Config.Racing.currency,reward); VORPAdapter.notify(src,('Novo recorde! Recompensa: $%d'):format(reward)) end
    TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

-- API server-side para scripts de propriedades/fazendas.
exports('RegisterPrivateStable',function(propertyKey,data)
    if type(data)~='table' or not propertyKey then return false end
    DB.insert([[INSERT INTO lrrp_private_stables(property_key,owner_identifier,owner_charidentifier,label,x,y,z,heading) VALUES(?,?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE owner_identifier=VALUES(owner_identifier),owner_charidentifier=VALUES(owner_charidentifier),label=VALUES(label),x=VALUES(x),y=VALUES(y),z=VALUES(z),heading=VALUES(heading)]],{
        tostring(propertyKey),data.identifier,data.charIdentifier,tostring(data.label or propertyKey),tonumber(data.x) or 0,tonumber(data.y) or 0,tonumber(data.z) or 0,tonumber(data.heading) or 0
    })
    return true
end)
exports('RemovePrivateStable',function(propertyKey) DB.update('DELETE FROM lrrp_private_stables WHERE property_key=?',{tostring(propertyKey)}); return true end)

AddEventHandler('playerDropped',function() ActiveRaces[source]=nil end)

RegisterCommand('veterinario',function(src,args)
    if src==0 then return end
    local job=VORPAdapter.job(src) or ''; if not Config.HealthSystem.vetJobs[job] then return VORPAdapter.notify(src,'Você não é veterinário.') end
    local target=tonumber(args[1]); local horseId=tonumber(args[2]); if not target or not horseId or GetPlayerPing(target)<=0 then return VORPAdapter.notify(src,'Uso: /veterinario ID_JOGADOR ID_CAVALO') end
    local tid,tcid=ident(target); local h=DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{horseId,tid,tcid}); if not h then return VORPAdapter.notify(src,'Cavalo do paciente não encontrado.') end
    if LRRPV7ConsumeProfessionalItem and not LRRPV7ConsumeProfessionalItem(src,'vet') then return end
    DB.update('UPDATE lrrp_horses SET health_state=?,health=GREATEST(health,85),stamina=GREATEST(stamina,80) WHERE id=?',{'{}',h.id})
    VORPAdapter.notify(src,'Tratamento realizado.'); VORPAdapter.notify(target,'Seu cavalo foi tratado por um veterinário.'); TriggerClientEvent('lrrp_stables:refreshV6',target)
end,false)

RegisterCommand('ferrador',function(src,args)
    if src==0 then return end
    local job=VORPAdapter.job(src) or ''; if not (Config.Farrier.jobs[job]) then return VORPAdapter.notify(src,'Você não é ferrador.') end
    local target=tonumber(args[1]); local horseId=tonumber(args[2]); local level=tonumber(args[3]); if not target or not horseId or not level or GetPlayerPing(target)<=0 then return VORPAdapter.notify(src,'Uso: /ferrador ID_JOGADOR ID_CAVALO NIVEL') end
    local tid,tcid=ident(target); local h=DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{horseId,tid,tcid}); if not h then return VORPAdapter.notify(src,'Cavalo do cliente não encontrado.') end
    local selected=nil; for _,u in ipairs(Config.Horseshoes.levels or {}) do if tonumber(u.level)==level then selected=u break end end; if not selected then return end
    if LRRPV7ConsumeProfessionalItem and not LRRPV7ConsumeProfessionalItem(src,'farrier') then return end
    local price=math.floor((tonumber(selected.price) or 0)*(1-(Config.Farrier.serviceDiscount or 0)))
    if not VORPAdapter.removeCurrency(target,selected.currency or 0,price) then return VORPAdapter.notify(src,'O cliente não possui saldo suficiente.') end
    local upgrades=decode(h.upgrades); if tonumber(upgrades.horseshoe or 0)>=level then return VORPAdapter.notify(src,'O cavalo já possui esta ferradura ou superior.') end
    upgrades.horseshoe=level; DB.update('UPDATE lrrp_horses SET upgrades=? WHERE id=?',{LRRP.SafeJsonEncode(upgrades),h.id})
    VORPAdapter.notify(src,'Serviço de ferrador concluído.'); VORPAdapter.notify(target,('Ferradura instalada por profissional: %s'):format(selected.label)); TriggerClientEvent('lrrp_stables:refreshV6',target)
end,false)
