LRRPV9Server = { tameTokens = {}, raceProgress = {} }

local function ident(src)
    local id,cid,c=VORPAdapter.identity(src)
    return id,cid,c
end
local function ranch(src)
    local id,cid=ident(src); if not id then return nil end
    return DB.single('SELECT * FROM lrrp_ranches WHERE identifier=? AND charidentifier=?',{id,cid})
end
local function mine(src,horseId)
    local id,cid=ident(src); if not id then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{tonumber(horseId),id,cid})
end
local function isAdmin(src)
    return src==0 or (Config.Admin.enabled and IsPlayerAceAllowed(src,Config.Admin.ace))
end
local function invReady() return GetResourceState('vorp_inventory')=='started' end
local function invCount(src,item)
    if not invReady() then return 0 end
    local ok,res=pcall(function() return exports.vorp_inventory:getItem(src,item) end)
    return ok and res and (tonumber(res.count) or 0) or 0
end
local function invSub(src,item,amount)
    amount=math.max(1,math.floor(tonumber(amount) or 1))
    if invCount(src,item)<amount then return false end
    local ok,res=pcall(function() return exports.vorp_inventory:subItem(src,item,amount) end)
    return ok and res~=false
end
local function invAdd(src,item,amount,metadata)
    if not invReady() then return false end
    local ok,res=pcall(function() return exports.vorp_inventory:addItem(src,item,amount,metadata or {}) end)
    return ok and res~=false
end
local function track(key)
    for _,t in ipairs(Config.AdvancedRacing.tracks or {}) do if t.key==key then return t end end
end
local function horseAllowed(model)
    for _,m in ipairs(Config.WildHorses.models or {}) do if m==model then return true end end
    return false
end
local function charJob(src)
    local j=VORPAdapter.job(src)
    return j and tostring(j) or ''
end
local function seasonKey()
    local prefix=Config.Seasons.prefix or 'Temporada'
    local days=math.max(1,tonumber(Config.Seasons.durationDays) or 30)
    local anchor=os.time({year=2026,month=1,day=1,hour=0})
    local idx=math.floor((os.time()-anchor)/(days*86400))+1
    return ('%s %d'):format(prefix,math.max(1,idx))
end

function LRRPV9Track(key) return track(key) end
function LRRPV9AttachOdds(room)
    if not room or not room.entries then return room end
    local total=tonumber(room.bet_total) or 0
    local base=Config.AdvancedRacing.baseOdds or 2.0
    for _,entry in ipairs(room.entries) do
        local onEntry=tonumber((DB.single('SELECT COALESCE(SUM(amount),0) total FROM lrrp_stable_race_bets WHERE event_id=? AND entry_id=?',{room.id,entry.id}) or {}).total) or 0
        if total<=0 or onEntry<=0 then entry.odds=base else entry.odds=math.max(1.05,math.floor((total/onEntry)*100)/100) end
    end
    return room
end
function LRRPV9ValidateFinish(src,eventId,trackKey)
    local t=track(trackKey)
    if not t or not t.checkpoints or #t.checkpoints==0 then return true end
    local p=LRRPV9Server.raceProgress[tonumber(eventId)] or {}
    return tonumber(p[src] or 0)>=#t.checkpoints
end

local function structuresFor(ranchId)
    return DB.query('SELECT * FROM lrrp_ranch_structures WHERE ranch_id=? ORDER BY id',{ranchId}) or {}
end
local function v9Data(src)
    local r=ranch(src)
    local out={ranch=r,structures={},transport=nil,wildZones=Config.WildHorses.zones,season=seasonKey(),seasonEndsInDays=0,adminStats=nil}
    if r then
        out.structures=structuresFor(r.id)
        out.transport=DB.single("SELECT t.*,h.name horse_name FROM lrrp_horse_transport t JOIN lrrp_horses h ON h.id=t.horse_id WHERE t.ranch_id=? AND t.status='loaded' ORDER BY t.id DESC LIMIT 1",{r.id})
    end
    if isAdmin(src) then
        out.adminStats={
            horses=tonumber((DB.single('SELECT COUNT(*) total FROM lrrp_horses',{}) or {}).total) or 0,
            ranches=tonumber((DB.single('SELECT COUNT(*) total FROM lrrp_ranches',{}) or {}).total) or 0,
            auctions=tonumber((DB.single("SELECT COUNT(*) total FROM lrrp_stable_auctions WHERE status='active'",{}) or {}).total) or 0,
            races=tonumber((DB.single("SELECT COUNT(*) total FROM lrrp_stable_race_events WHERE status IN ('open','running')",{}) or {}).total) or 0,
            payouts=tonumber((DB.single('SELECT COALESCE(SUM(amount),0) total FROM lrrp_stable_payouts',{}) or {}).total) or 0
        }
    end
    TriggerClientEvent('lrrp_stables:v9DataClient',src,out)
end
RegisterNetEvent('lrrp_stables:v9Data',function() v9Data(source) end)

RegisterNetEvent('lrrp_stables:buildRanchStructure',function(kind,coords)
    local src=source; local r=ranch(src); if not r then return VORPAdapter.notify(src,'Crie um rancho antes de construir.') end
    local def=Config.RanchBuilding.structures[tostring(kind or '')]; if not def then return end
    local count=tonumber((DB.single('SELECT COUNT(*) total FROM lrrp_ranch_structures WHERE ranch_id=? AND structure_key=?',{r.id,kind}) or {}).total) or 0
    if count>=(def.max or 1) then return VORPAdapter.notify(src,'Limite desta estrutura atingido.') end
    coords=type(coords)=='table' and coords or {}
    local x,y,z=tonumber(coords.x) or r.x,tonumber(coords.y) or r.y,tonumber(coords.z) or r.z
    local dx,dy,dz=x-r.x,y-r.y,z-r.z
    if math.sqrt(dx*dx+dy*dy+dz*dz)>(Config.RanchBuilding.maxBuildDistance or 45.0) then return VORPAdapter.notify(src,'Construa dentro da área do seu rancho.') end
    if not VORPAdapter.removeCurrency(src,0,def.price or 0) then return VORPAdapter.notify(src,'Dinheiro insuficiente para construir.') end
    DB.insert('INSERT INTO lrrp_ranch_structures(ranch_id,structure_key,label,level,x,y,z,heading) VALUES(?,?,?,?,?,?,?,?)',{r.id,kind,def.label,1,x,y,z,tonumber(coords.heading) or 0})
    if kind=='pasture_fence' then DB.update('UPDATE lrrp_ranches SET pasture_capacity=LEAST(24,pasture_capacity+?) WHERE id=?',{def.capacityBonus or 2,r.id}) end
    VORPAdapter.notify(src,def.label..' construída.'); v9Data(src)
end)

RegisterNetEvent('lrrp_stables:stockPhysicalRanch',function(kind,amount)
    local src=source; local r=ranch(src); if not r then return end
    amount=math.max(1,math.min(50,math.floor(tonumber(amount) or 1)))
    local item,field,units
    if kind=='hay' then item=Config.PhysicalStock.hayItem; field='hay_stock'; units=Config.PhysicalStock.hayUnitsPerItem
    elseif kind=='water' then item=Config.PhysicalStock.waterItem; field='water_stock'; units=Config.PhysicalStock.waterUnitsPerItem else return end
    if not invSub(src,item,amount) then return VORPAdapter.notify(src,'Você não possui o item necessário: '..item) end
    local add=amount*(units or 1)
    DB.update(('UPDATE lrrp_ranches SET %s=LEAST(?,%s+?) WHERE id=?'):format(field,field),{Config.PhysicalStock.maxStock,add,r.id})
    DB.insert('INSERT INTO lrrp_ranch_stock_logs(ranch_id,stock_type,amount,reason) VALUES(?,?,?,?)',{r.id,kind,add,'abastecimento'})
    VORPAdapter.notify(src,'Estoque físico atualizado.'); v9Data(src)
end)

RegisterNetEvent('lrrp_stables:loadHorseTransport',function(horseId)
    local src=source; local r=ranch(src); local h=mine(src,horseId); if not r or not h then return end
    if h.death_state~='alive' then return VORPAdapter.notify(src,'Este cavalo não pode ser transportado.') end
    local active=DB.single("SELECT id FROM lrrp_horse_transport WHERE ranch_id=? AND status='loaded'",{r.id}); if active then return VORPAdapter.notify(src,'A carroça já transporta um cavalo.') end
    DB.insert("INSERT INTO lrrp_horse_transport(ranch_id,horse_id,identifier,charidentifier,status,loaded_at) VALUES(?,?,?,?, 'loaded',NOW())",{r.id,h.id,h.identifier,h.charidentifier})
    DB.update("UPDATE lrrp_horses SET transport_state='loaded' WHERE id=?",{h.id})
    TriggerClientEvent('lrrp_stables:forceDismiss',src,h.id)
    TriggerClientEvent('lrrp_stables:spawnTransportWagonClient',src,{horseId=h.id,horseName=h.name})
    VORPAdapter.notify(src,'Cavalo carregado para transporte.'); v9Data(src)
end)
RegisterNetEvent('lrrp_stables:unloadHorseTransport',function()
    local src=source; local r=ranch(src); if not r then return end
    local t=DB.single("SELECT * FROM lrrp_horse_transport WHERE ranch_id=? AND status='loaded' ORDER BY id DESC LIMIT 1",{r.id}); if not t then return VORPAdapter.notify(src,'Nenhum cavalo está carregado.') end
    DB.update("UPDATE lrrp_horse_transport SET status='unloaded',unloaded_at=NOW() WHERE id=?",{t.id}); DB.update("UPDATE lrrp_horses SET transport_state='none' WHERE id=?",{t.horse_id})
    TriggerClientEvent('lrrp_stables:removeTransportWagonClient',src)
    VORPAdapter.notify(src,'Cavalo descarregado.'); v9Data(src)
end)

RegisterNetEvent('lrrp_stables:requestWildTame',function(model)
    local src=source; model=tostring(model or '')
    if not Config.WildHorses.enabled or not horseAllowed(model) then return end
    local id,cid=ident(src); if not id then return end
    local token=('%s:%s:%s'):format(src,os.time(),math.random(10000,99999))
    LRRPV9Server.tameTokens[src]={token=token,model=model,expires=os.time()+120}
    TriggerClientEvent('lrrp_stables:startTamingMinigameClient',src,{token=token,model=model,steps=Config.WildHorses.tameSteps})
end)
RegisterNetEvent('lrrp_stables:completeWildTame',function(token,name)
    local src=source; if Config.Release then return VORPAdapter.notify(src,'Use o fluxo de doma da v1.0 para nomear o cavalo.') end; local pending=LRRPV9Server.tameTokens[src]
    if not pending or pending.token~=token or pending.expires<os.time() then return VORPAdapter.notify(src,'Tentativa de doma expirada.') end
    LRRPV9Server.tameTokens[src]=nil
    local id,cid=ident(src); if not id then return end
    local count=tonumber((DB.single('SELECT COUNT(*) total FROM lrrp_horses WHERE identifier=? AND charidentifier=?',{id,cid}) or {}).total) or 0
    if count>=Config.MaxHorses then return VORPAdapter.notify(src,'Você atingiu o limite de cavalos.') end
    local sex=math.random(1,2)==1 and 'male' or 'female'
    local horseId=DB.insert([[INSERT INTO lrrp_horses(identifier,charidentifier,name,model,is_primary,price,purchase_currency,health,stamina,hunger,thirst,cleanliness,xp,bonding,training,accessories,weapon_storage,upgrades,sex,birth_at,genetics,health_state,life_stage,rarity,mutation,death_state,wild_origin,tamed_at,transport_state)
      VALUES(?,?,?,?,0,0,0,90,90,70,70,55,0,0,0,'{}','{}','{}',?,NOW(),'{}','{}','adult','common','{}','alive',1,NOW(),'none')]],{id,cid,tostring(name or 'Cavalo Selvagem'):sub(1,32),pending.model,sex})
    VORPAdapter.notify(src,('Doma concluída! Cavalo #%d registrado no estábulo.'):format(horseId)); TriggerClientEvent('lrrp_stables:refreshV6',src); v9Data(src)
end)

RegisterNetEvent('lrrp_stables:professionalVetTreat',function(horseId)
    local src=source; if not Config.HealthSystem.vetJobs[charJob(src)] then return VORPAdapter.notify(src,'Você não é veterinário.') end
    local h=mine(src,horseId); if not h then return end
    if not invSub(src,Config.ProfessionalItems.vet.item,Config.ProfessionalItems.vet.amount or 1) then return VORPAdapter.notify(src,'Falta '..Config.ProfessionalItems.vet.item..'.') end
    DB.update("UPDATE lrrp_horses SET health=LEAST(100,health+35),stamina=LEAST(100,stamina+20),health_state='{}' WHERE id=?",{h.id})
    VORPAdapter.notify(src,'Tratamento veterinário concluído.'); TriggerClientEvent('lrrp_stables:refreshV6',src)
end)
RegisterNetEvent('lrrp_stables:professionalFarrierComplete',function(horseId,level)
    local src=source; if not Config.Farrier.jobs[charJob(src)] then return VORPAdapter.notify(src,'Você não é ferrador.') end
    local h=mine(src,horseId); level=math.max(1,math.min(3,tonumber(level) or 1)); if not h then return end
    if not invSub(src,Config.ProfessionalItems.farrier.item,Config.ProfessionalItems.farrier.amount or 1) then return VORPAdapter.notify(src,'Falta '..Config.ProfessionalItems.farrier.item..'.') end
    local up=LRRP.SafeJsonDecode(h.upgrades); up.horseshoe=level
    DB.update('UPDATE lrrp_horses SET upgrades=?,horseshoe_durability=100 WHERE id=?',{LRRP.SafeJsonEncode(up),h.id})
    VORPAdapter.notify(src,'Ferradura instalada pelo minigame.'); TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

RegisterNetEvent('lrrp_stables:raceCheckpointV9',function(eventId,index)
    local src=source; eventId=tonumber(eventId); index=tonumber(index); if not eventId or not index then return end
    local e=DB.single("SELECT track_key FROM lrrp_stable_race_events WHERE id=? AND status='running'",{eventId}); if not e then return end
    local t=track(e.track_key); if not t or not t.checkpoints[index] then return end
    local ped=GetPlayerPed(src); if ped and ped~=0 then
        local c=GetEntityCoords(ped); local cp=t.checkpoints[index]; local dx,dy,dz=c.x-cp.x,c.y-cp.y,c.z-cp.z
        if math.sqrt(dx*dx+dy*dy+dz*dz)>18.0 then return end
    end
    LRRPV9Server.raceProgress[eventId]=LRRPV9Server.raceProgress[eventId] or {}
    local current=tonumber(LRRPV9Server.raceProgress[eventId][src] or 0)
    if index==current+1 then LRRPV9Server.raceProgress[eventId][src]=index end
end)

RegisterNetEvent('lrrp_stables:staffEconomyAction',function(action,value)
    local src=source; if not isAdmin(src) then return end
    action=tostring(action or ''); value=math.max(0,math.floor(tonumber(value) or 0))
    if action=='clearPayouts' then DB.update('DELETE FROM lrrp_stable_payouts',{})
    elseif action=='setMarketLimit' then Config.Market.maxPrice=math.max(Config.Market.minPrice,value)
    elseif action=='finishOpenRaces' then DB.update("UPDATE lrrp_stable_race_events SET status='finished',finished_at=NOW() WHERE status='open'",{})
    else return end
    VORPAdapter.notify(src,'Ação econômica do staff executada.'); v9Data(src)
end)


local function finalizeAutomaticSeasons()
    if not Config.Seasons.automatic then return end
    local current=seasonKey()
    local seasons=DB.query('SELECT DISTINCT season FROM lrrp_stable_championship_points WHERE season<>?',{current}) or {}
    for _,row in ipairs(seasons) do
        local season=row.season
        local done=DB.single('SELECT finalized_at FROM lrrp_stable_seasons WHERE season=?',{season})
        if not done or not done.finalized_at then
            local top=DB.query('SELECT * FROM lrrp_stable_championship_points WHERE season=? ORDER BY points DESC,wins DESC,races ASC LIMIT 3',{season}) or {}
            for i,r in ipairs(top) do
                local reward=Config.Championship.podiumRewards[i] or 0
                if reward>0 then DB.insert('INSERT INTO lrrp_stable_payouts(identifier,charidentifier,amount,currency,reason) VALUES(?,?,?,?,?)',{r.identifier,r.charidentifier,reward,Config.Championship.currency,('Premiação automática %s - %dº lugar'):format(season,i)}) end
            end
            DB.insert('INSERT INTO lrrp_stable_seasons(season,finalized_at) VALUES(?,NOW()) ON DUPLICATE KEY UPDATE finalized_at=NOW()',{season})
        end
    end
    DB.insert('INSERT INTO lrrp_stable_seasons(season,finalized_at) VALUES(?,NULL) ON DUPLICATE KEY UPDATE season=VALUES(season)',{current})
end

local function physicalCare()
    if not Config.PhysicalStock.enabled then return end
    local rows=DB.query('SELECT * FROM lrrp_ranches WHERE hay_stock>0 OR water_stock>0',{}) or {}
    for _,r in ipairs(rows) do
        local workers=tonumber((DB.single("SELECT COUNT(*) total FROM lrrp_ranch_workers WHERE ranch_id=? AND status='active'",{r.id}) or {}).total) or 0
        if workers>0 and (tonumber(r.operating_debt) or 0)<=0 then
            local horses=tonumber((DB.single("SELECT COUNT(*) total FROM lrrp_horses WHERE ranch_id=? AND death_state='alive'",{r.id}) or {}).total) or 0
            if horses>0 then
                local hayNeed=math.min(tonumber(r.hay_stock) or 0,horses)
                local waterNeed=math.min(tonumber(r.water_stock) or 0,horses)
                if hayNeed>0 then DB.update('UPDATE lrrp_ranches SET hay_stock=GREATEST(0,hay_stock-?) WHERE id=?',{hayNeed,r.id}); DB.update("UPDATE lrrp_horses SET hunger=LEAST(100,hunger+?) WHERE ranch_id=? AND death_state='alive'",{Config.PhysicalStock.hungerRestore,r.id}) end
                if waterNeed>0 then DB.update('UPDATE lrrp_ranches SET water_stock=GREATEST(0,water_stock-?) WHERE id=?',{waterNeed,r.id}); DB.update("UPDATE lrrp_horses SET thirst=LEAST(100,thirst+?) WHERE ranch_id=? AND death_state='alive'",{Config.PhysicalStock.thirstRestore,r.id}) end
            end
        end
    end
end

CreateThread(function()
    Wait(15000)
    while true do
        Config.Championship.season=seasonKey()
        finalizeAutomaticSeasons()
        physicalCare()
        Wait((Config.PhysicalStock.autoConsumeMinutes or 30)*60000)
    end
end)

AddEventHandler('playerDropped',function() LRRPV9Server.tameTokens[source]=nil end)
