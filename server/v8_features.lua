LRRPV8Server = { rooms = {} }

local function ident(src)
    local id,cid,c=VORPAdapter.identity(src)
    return id,cid,c
end
local function encode(v) return LRRP.SafeJsonEncode(v or {}) end
local function decode(v) return LRRP.SafeJsonDecode(v) end
local function nowPlusHours(hours) return os.date('%Y-%m-%d %H:%M:%S',os.time()+math.floor((tonumber(hours) or 0)*3600)) end
local function isAdmin(src)
    return src==0 or (Config.Admin.enabled and IsPlayerAceAllowed(src,Config.Admin.ace))
end
local function isJockey(src)
    return Config.Jockey.jobs[VORPAdapter.job(src) or ''] == true
end
local function mine(src,horseId)
    local id,cid=ident(src); if not id then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{tonumber(horseId),id,cid})
end
local function ranch(src)
    local id,cid=ident(src); if not id then return nil end
    return DB.single('SELECT * FROM lrrp_ranches WHERE identifier=? AND charidentifier=?',{id,cid})
end
local function invReady() return GetResourceState('vorp_inventory')=='started' end
local function invCount(src,item)
    if not invReady() then return 0 end
    local ok,res=pcall(function() return exports.vorp_inventory:getItem(src,item) end)
    return ok and res and (tonumber(res.count) or 0) or 0
end
local function invSub(src,item,amount)
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
    for _,t in ipairs((Config.Racing and Config.Racing.tracks) or {}) do if t.key==key then return t end end
end
local function roomRows()
    local rows=DB.query("SELECT * FROM lrrp_stable_race_events WHERE status IN ('open','running') ORDER BY id DESC LIMIT 25",{}) or {}
    for _,r in ipairs(rows) do
        r.entries=DB.query('SELECT id,horse_id,horse_name,charidentifier,finish_ms,position,status,is_jockey FROM lrrp_stable_race_entries WHERE event_id=? ORDER BY id',{r.id}) or {}
        r.bet_total=tonumber((DB.single('SELECT COALESCE(SUM(amount),0) total FROM lrrp_stable_race_bets WHERE event_id=?',{r.id}) or {}).total) or 0
        if LRRPV9AttachOdds then LRRPV9AttachOdds(r) end
    end
    return rows
end
local function ranchOpsData(src)
    local r=ranch(src)
    if not r then return {ranch=nil,workers={},horses={},isJockey=isJockey(src),isAdmin=isAdmin(src),raceRooms=roomRows()} end
    local workers=DB.query('SELECT * FROM lrrp_ranch_workers WHERE ranch_id=? ORDER BY id',{r.id}) or {}
    local horses=DB.query("SELECT id,name,model,hunger,thirst,cleanliness,life_stage,death_state FROM lrrp_horses WHERE ranch_id=? AND death_state='alive' ORDER BY id",{r.id}) or {}
    return {ranch=r,workers=workers,horses=horses,isJockey=isJockey(src),isAdmin=isAdmin(src),raceRooms=roomRows()}
end
local function sendData(src)
    TriggerClientEvent('lrrp_stables:v8DataClient',src,ranchOpsData(src))
end
RegisterNetEvent('lrrp_stables:v8Data',function() sendData(source) end)

RegisterNetEvent('lrrp_stables:stockRanchFeed',function(amount)
    local src=source; local r=ranch(src); if not r then return VORPAdapter.notify(src,'Crie um rancho primeiro.') end
    amount=math.max(1,math.min(100,math.floor(tonumber(amount) or 1)))
    if not invSub(src,Config.RanchAutomation.stockItem,amount) then return VORPAdapter.notify(src,'Você não possui ração suficiente no inventário.') end
    local units=amount*(Config.RanchAutomation.stockPerItem or 1)
    local newStock=math.min(Config.RanchAutomation.maxStock,(tonumber(r.feed_stock) or 0)+units)
    DB.update('UPDATE lrrp_ranches SET feed_stock=? WHERE id=?',{newStock,r.id})
    VORPAdapter.notify(src,('Estoque do rancho: %d unidades.'):format(newStock)); sendData(src)
end)

RegisterNetEvent('lrrp_stables:stockRanchWater',function(amount)
    local src=source
    local r=ranch(src)
    if not r then return VORPAdapter.notify(src,'Crie um rancho primeiro.') end

    amount=math.max(1,math.min(100,math.floor(tonumber(amount) or 1)))
    local item=Config.RanchAutomation.waterItem or 'water_bucket'

    if not invSub(src,item,amount) then
        return VORPAdapter.notify(src,('Você precisa de %dx %s.'):format(amount,item))
    end

    local units=amount*(Config.RanchAutomation.waterPerItem or 1)
    local newStock=math.min(Config.RanchAutomation.maxStock,(tonumber(r.water_stock) or 0)+units)

    DB.update('UPDATE lrrp_ranches SET water_stock=? WHERE id=?',{newStock,r.id})
    VORPAdapter.notify(src,('Água do rancho: %d unidades.'):format(newStock))
    sendData(src)
end)

RegisterNetEvent('lrrp_stables:hireRanchWorker',function(name)
    local src=source; local r=ranch(src); if not r then return end
    local c=DB.single('SELECT COUNT(*) total FROM lrrp_ranch_workers WHERE ranch_id=?',{r.id})
    if (tonumber(c and c.total) or 0)>=Config.RanchAutomation.maxWorkers then return VORPAdapter.notify(src,'Limite de empregados atingido.') end
    if not VORPAdapter.removeCurrency(src,0,Config.RanchAutomation.workerHirePrice) then return VORPAdapter.notify(src,'Dinheiro insuficiente para contratar.') end
    DB.insert("INSERT INTO lrrp_ranch_workers(ranch_id,name,role,wage,status) VALUES(?,?,'caretaker',?,'active')",{r.id,tostring(name or 'Tratador'):sub(1,40),Config.RanchAutomation.workerMonthlyWage})
    VORPAdapter.notify(src,'Tratador contratado.'); sendData(src)
end)
RegisterNetEvent('lrrp_stables:fireRanchWorker',function(workerId)
    local src=source; local r=ranch(src); if not r then return end
    DB.update('DELETE FROM lrrp_ranch_workers WHERE id=? AND ranch_id=?',{tonumber(workerId),r.id}); VORPAdapter.notify(src,'Empregado dispensado.'); sendData(src)
end)

RegisterNetEvent('lrrp_stables:showPasture',function()
    local src=source; local r=ranch(src); if not r then return end
    local horses=DB.query("SELECT id,name,model FROM lrrp_horses WHERE ranch_id=? AND death_state='alive' AND life_stage<>'deceased' ORDER BY id LIMIT ?",{r.id,Config.RanchAutomation.pastureMaxHorses}) or {}
    local workers=DB.query("SELECT id,name FROM lrrp_ranch_workers WHERE ranch_id=? AND status='active' ORDER BY id LIMIT 3",{r.id}) or {}
    TriggerClientEvent('lrrp_stables:pastureClient',src,{ranch=r,horses=horses,workers=workers})
end)

local function processRanches()
    if not Config.RanchAutomation.enabled then return end
    local rows=DB.query('SELECT * FROM lrrp_ranches',{}) or {}
    for _,r in ipairs(rows) do
        local workers=tonumber((DB.single("SELECT COUNT(*) total FROM lrrp_ranch_workers WHERE ranch_id=? AND status='active'",{r.id}) or {}).total) or 0
        if workers>0 and (tonumber(r.operating_debt) or 0)<=0 then
            local horses=DB.query("SELECT id FROM lrrp_horses WHERE ranch_id=? AND death_state='alive'",{r.id}) or {}
            local neededFeed=#horses*(Config.RanchAutomation.feedCostPerHorse or 1)
            local neededWater=#horses*(Config.RanchAutomation.waterCostPerHorse or 1)
            local feed=tonumber(r.feed_stock) or 0
            local water=tonumber(r.water_stock) or 0

            if #horses>0 and feed>=neededFeed and water>=neededWater then
                DB.update([[
                    UPDATE lrrp_ranches
                    SET feed_stock=GREATEST(0,feed_stock-?),
                        water_stock=GREATEST(0,water_stock-?),
                        last_auto_care=NOW()
                    WHERE id=?
                ]],{neededFeed,neededWater,r.id})

                DB.update([[
                    UPDATE lrrp_horses
                    SET hunger=LEAST(100,hunger+?),
                        thirst=LEAST(100,thirst+?),
                        cleanliness=LEAST(100,cleanliness+?)
                    WHERE ranch_id=? AND death_state='alive'
                ]],{
                    Config.RanchAutomation.hungerRestore,
                    Config.RanchAutomation.thirstRestore,
                    Config.RanchAutomation.cleanlinessRestore,
                    r.id
                })

                print(('[estabulo_VT] RANCHO AUTO CUIDADO | rancho=%s cavalos=%s racao=%s agua=%s'):format(
                    tostring(r.id),tostring(#horses),tostring(neededFeed),tostring(neededWater)
                ))
            end
        end
        local due=DB.single('SELECT next_bill_at<=NOW() due FROM lrrp_ranches WHERE id=?',{r.id})
        if due and tonumber(due.due)==1 then
            local wage=workers*(Config.RanchAutomation.workerMonthlyWage or 0)
            if wage>0 then DB.update('UPDATE lrrp_ranches SET operating_debt=operating_debt+? WHERE id=?',{wage,r.id}) end
            DB.update('UPDATE lrrp_ranches SET next_bill_at=? WHERE id=?',{nowPlusHours(Config.RanchAutomation.billingHours),r.id})
        end
    end
end

RegisterNetEvent('lrrp_stables:payRanchDebt',function()
    local src=source; local r=ranch(src); if not r then return end
    local debt=math.max(0,tonumber(r.operating_debt) or 0); if debt<=0 then return VORPAdapter.notify(src,'O rancho não possui dívida operacional.') end
    if not VORPAdapter.removeCurrency(src,0,debt) then return VORPAdapter.notify(src,'Dinheiro insuficiente para quitar a folha do rancho.') end
    DB.update('UPDATE lrrp_ranches SET operating_debt=0 WHERE id=?',{r.id}); VORPAdapter.notify(src,'Folha do rancho quitada. O cuidado automático foi reativado.'); sendData(src)
end)

local function raceFee(src)
    local fee=Config.MultiplayerRacing.entryFee or 0
    if isJockey(src) then fee=math.floor(fee*(1-(Config.Jockey.entryDiscount or 0))) end
    return fee
end
RegisterNetEvent('lrrp_stables:createRaceRoom',function(trackKey,horseId)
    local src=source; if not Config.MultiplayerRacing.enabled then return end
    local id,cid=ident(src); local h=mine(src,horseId); local t=track(trackKey)
    if not id or not h or not t then return VORPAdapter.notify(src,'Pista ou cavalo inválido.') end
    if h.death_state~='alive' or h.life_stage~='adult' then return VORPAdapter.notify(src,'Este cavalo não pode competir.') end
    local fee=raceFee(src); if not VORPAdapter.removeCurrency(src,Config.MultiplayerRacing.currency,fee) then return VORPAdapter.notify(src,'Saldo insuficiente para inscrição.') end
    local eventId=DB.insert("INSERT INTO lrrp_stable_race_events(track_key,host_identifier,host_charidentifier,status,entry_fee,currency,pot,created_at) VALUES(?,?,?,'open',?,?,?,NOW())",{trackKey,id,cid,fee,Config.MultiplayerRacing.currency,fee})
    DB.insert("INSERT INTO lrrp_stable_race_entries(event_id,identifier,charidentifier,horse_id,horse_name,status,is_jockey) VALUES(?,?,?,?,?,'joined',?)",{eventId,id,cid,h.id,h.name,isJockey(src) and 1 or 0})
    VORPAdapter.notify(src,'Sala de corrida criada.'); sendData(src)
end)
RegisterNetEvent('lrrp_stables:joinRaceRoom',function(eventId,horseId)
    local src=source; local id,cid=ident(src); local h=mine(src,horseId); if not id or not h then return end
    local e=DB.single("SELECT * FROM lrrp_stable_race_events WHERE id=? AND status='open'",{tonumber(eventId)}); if not e then return VORPAdapter.notify(src,'Sala fechada.') end
    local count=tonumber((DB.single('SELECT COUNT(*) total FROM lrrp_stable_race_entries WHERE event_id=?',{e.id}) or {}).total) or 0
    if count>=Config.MultiplayerRacing.maxPlayers then return VORPAdapter.notify(src,'Sala lotada.') end
    local exists=DB.single('SELECT id FROM lrrp_stable_race_entries WHERE event_id=? AND identifier=? AND charidentifier=?',{e.id,id,cid}); if exists then return VORPAdapter.notify(src,'Você já está inscrito.') end
    local fee=raceFee(src); if not VORPAdapter.removeCurrency(src,e.currency,fee) then return VORPAdapter.notify(src,'Saldo insuficiente para inscrição.') end
    DB.insert("INSERT INTO lrrp_stable_race_entries(event_id,identifier,charidentifier,horse_id,horse_name,status,is_jockey) VALUES(?,?,?,?,?,'joined',?)",{e.id,id,cid,h.id,h.name,isJockey(src) and 1 or 0}); DB.update('UPDATE lrrp_stable_race_events SET pot=pot+? WHERE id=?',{fee,e.id}); VORPAdapter.notify(src,'Inscrição confirmada.'); sendData(src)
end)
RegisterNetEvent('lrrp_stables:betRace',function(eventId,entryId,amount)
    local src=source; if not Config.MultiplayerRacing.betting then return end
    local id,cid=ident(src); local e=DB.single("SELECT * FROM lrrp_stable_race_events WHERE id=? AND status='open'",{tonumber(eventId)}); if not id or not e then return end
    amount=math.max(Config.MultiplayerRacing.minBet,math.min(Config.MultiplayerRacing.maxBet,math.floor(tonumber(amount) or 0)))
    local entry=DB.single('SELECT id FROM lrrp_stable_race_entries WHERE id=? AND event_id=?',{tonumber(entryId),e.id}); if not entry then return end
    if not VORPAdapter.removeCurrency(src,e.currency,amount) then return VORPAdapter.notify(src,'Saldo insuficiente para apostar.') end
    DB.insert('INSERT INTO lrrp_stable_race_bets(event_id,entry_id,identifier,charidentifier,amount,currency) VALUES(?,?,?,?,?,?)',{e.id,entry.id,id,cid,amount,e.currency}); VORPAdapter.notify(src,'Aposta registrada.'); sendData(src)
end)
local function onlineSource(identifier,charidentifier)
    for _,p in ipairs(GetPlayers()) do local s=tonumber(p); local id,cid=ident(s); if id==identifier and tonumber(cid)==tonumber(charidentifier) then return s end end
end
RegisterNetEvent('lrrp_stables:startRaceRoom',function(eventId)
    local src=source; local id,cid=ident(src); local e=DB.single("SELECT * FROM lrrp_stable_race_events WHERE id=? AND status='open'",{tonumber(eventId)}); if not e or e.host_identifier~=id or tonumber(e.host_charidentifier)~=cid then return VORPAdapter.notify(src,'Somente o criador pode iniciar.') end
    local entries=DB.query('SELECT * FROM lrrp_stable_race_entries WHERE event_id=?',{e.id}) or {}; if #entries<Config.MultiplayerRacing.minPlayers then return VORPAdapter.notify(src,'Jogadores insuficientes para largar.') end
    DB.update("UPDATE lrrp_stable_race_events SET status='running',started_at=NOW() WHERE id=?",{e.id})
    if LRRPV9Server and LRRPV9Server.raceProgress then LRRPV9Server.raceProgress[e.id]={} end
    for _,entry in ipairs(entries) do local target=onlineSource(entry.identifier,entry.charidentifier); if target then local evt=(LRRPV9Track and LRRPV9Track(e.track_key)) and 'lrrp_stables:startAdvancedRaceClient' or 'lrrp_stables:startMultiplayerRaceClient'; TriggerClientEvent(evt,target,{eventId=e.id,trackKey=e.track_key,horseId=entry.horse_id,countdown=Config.MultiplayerRacing.countdownSeconds}) end end
end)
local function finalizeRace(eventId)
    local e=DB.single('SELECT * FROM lrrp_stable_race_events WHERE id=?',{eventId}); if not e or e.status=='finished' then return end
    local finishers=DB.query("SELECT * FROM lrrp_stable_race_entries WHERE event_id=? AND status='finished' ORDER BY position ASC",{eventId}) or {}
    local pot=tonumber(e.pot) or 0
    for i=1,math.min(3,#finishers) do
        local row=finishers[i]; local split=Config.MultiplayerRacing.podiumSplit[i] or 0; local reward=math.floor(pot*split); if tonumber(row.is_jockey)==1 then reward=math.floor(reward*(1+(Config.Jockey.rewardBonus or 0))) end
        if reward>0 then DB.insert('INSERT INTO lrrp_stable_payouts(identifier,charidentifier,amount,currency,reason) VALUES(?,?,?,?,?)',{row.identifier,row.charidentifier,reward,e.currency,('Pódio corrida multiplayer %dº'):format(i)}) end
        local target=onlineSource(row.identifier,row.charidentifier); if target and Config.Trophy.enabled then invAdd(target,Config.Trophy.item,1,{event_id=eventId,position=i,track=e.track_key,horse=row.horse_name,earned_at=os.date('%Y-%m-%d %H:%M:%S')}) end
    end
    if #finishers>0 then
        local winner=finishers[1]
        local total=tonumber((DB.single('SELECT COALESCE(SUM(amount),0) total FROM lrrp_stable_race_bets WHERE event_id=?',{eventId}) or {}).total) or 0
        local winTotal=tonumber((DB.single('SELECT COALESCE(SUM(amount),0) total FROM lrrp_stable_race_bets WHERE event_id=? AND entry_id=?',{eventId,winner.id}) or {}).total) or 0
        if total>0 and winTotal>0 then
            local pool=math.floor(total*(1-(Config.MultiplayerRacing.houseCut or 0)))
            local bets=DB.query('SELECT * FROM lrrp_stable_race_bets WHERE event_id=? AND entry_id=?',{eventId,winner.id}) or {}
            for _,b in ipairs(bets) do local payout=math.floor(pool*((tonumber(b.amount) or 0)/winTotal)); if payout>0 then DB.insert('INSERT INTO lrrp_stable_payouts(identifier,charidentifier,amount,currency,reason) VALUES(?,?,?,?,?)',{b.identifier,b.charidentifier,payout,b.currency,'Aposta vencedora em corrida'}) end end
        end
    end
    DB.update("UPDATE lrrp_stable_race_events SET status='finished',finished_at=NOW() WHERE id=?",{eventId})
end
RegisterNetEvent('lrrp_stables:finishMultiplayerRace',function(eventId,timeMs)
    local src=source; local id,cid=ident(src); local e=DB.single("SELECT * FROM lrrp_stable_race_events WHERE id=? AND status='running'",{tonumber(eventId)}); if not id or not e then return end
    local t=track(e.track_key); if not t then return end; if LRRPV9ValidateFinish and not LRRPV9ValidateFinish(src,e.id,e.track_key) then return VORPAdapter.notify(src,'Passe por todos os checkpoints antes da chegada.') end; local ped=GetPlayerPed(src); if ped and ped~=0 then local c=GetEntityCoords(ped); local dx,dy,dz=c.x-t.finish.x,c.y-t.finish.y,c.z-t.finish.z; if math.sqrt(dx*dx+dy*dy+dz*dz)>18.0 then return end end
    timeMs=math.floor(tonumber(timeMs) or 0); if timeMs<5000 or timeMs>(Config.MultiplayerRacing.finishTimeoutSeconds*1000) then return end
    local row=DB.single("SELECT * FROM lrrp_stable_race_entries WHERE event_id=? AND identifier=? AND charidentifier=? AND status='joined'",{e.id,id,cid}); if not row then return end
    local pos=tonumber((DB.single("SELECT COUNT(*)+1 pos FROM lrrp_stable_race_entries WHERE event_id=? AND status='finished'",{e.id}) or {}).pos) or 1
    DB.update("UPDATE lrrp_stable_race_entries SET finish_ms=?,position=?,status='finished' WHERE id=?",{timeMs,pos,row.id})
    VORPAdapter.notify(src,('Você terminou em %dº lugar.'):format(pos))
    local total=tonumber((DB.single('SELECT COUNT(*) total FROM lrrp_stable_race_entries WHERE event_id=?',{e.id}) or {}).total) or 0; local done=tonumber((DB.single("SELECT COUNT(*) total FROM lrrp_stable_race_entries WHERE event_id=? AND status='finished'",{e.id}) or {}).total) or 0
    if done>=total then finalizeRace(e.id) end
end)

RegisterNetEvent('lrrp_stables:adminHorse',function(horseId,action,value)
    local src=source; if not isAdmin(src) then return end
    horseId=tonumber(horseId); local h=horseId and DB.single('SELECT * FROM lrrp_horses WHERE id=?',{horseId}) or nil; if not h then return VORPAdapter.notify(src,'Cavalo não encontrado.') end
    action=tostring(action or '')
    if action=='heal' then DB.update("UPDATE lrrp_horses SET health=100,stamina=100,hunger=100,thirst=100,cleanliness=100,health_state='{}',death_state='alive' WHERE id=?",{horseId})
    elseif action=='xp' then DB.update('UPDATE lrrp_horses SET xp=? WHERE id=?',{math.max(0,tonumber(value) or 0),horseId})
    elseif action=='delete' then HorseInventory.delete(horseId); DB.update('DELETE FROM lrrp_horses WHERE id=?',{horseId})
    elseif action=='revive' then DB.update("UPDATE lrrp_horses SET death_state='alive',life_stage='adult',health=100,stamina=100 WHERE id=?",{horseId})
    else return end
    VORPAdapter.notify(src,'Ação administrativa executada.'); sendData(src); TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

CreateThread(function()
    Wait(10000)
    while true do
        processRanches()
        local cutoff=os.date('%Y-%m-%d %H:%M:%S',os.time()-(Config.MultiplayerRacing.finishTimeoutSeconds or 180)); local stale=DB.query("SELECT id FROM lrrp_stable_race_events WHERE status='running' AND started_at<?",{cutoff}) or {}
        for _,e in ipairs(stale) do finalizeRace(e.id) end
        Wait((Config.RanchAutomation.autoCareIntervalMinutes or 30)*60000)
    end
end)
