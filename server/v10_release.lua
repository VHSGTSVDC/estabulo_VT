-- LRRP_Stables v1.0.0 - release/production layer
LRRPV10 = { wearThrottle = {}, trainingTokens = {}, vetTokens = {} }

local function identity(src)
    local identifier,charId,char = VORPAdapter.identity(src)
    return identifier,charId,char
end

local function ranchOf(src)
    local identifier,charId = identity(src)
    if not identifier then return nil end
    return DB.single('SELECT * FROM lrrp_ranches WHERE identifier=? AND charidentifier=?',{identifier,charId})
end

local function ownedHorse(src,horseId)
    local identifier,charId = identity(src)
    if not identifier then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{tonumber(horseId),identifier,charId})
end

local function playerNameSafe(src)
    return GetPlayerName(src) or ('ID '..tostring(src))
end

local function webhook(title,description)
    local url = Config.Release and Config.Release.webhookUrl or ''
    if type(url)~='string' or url=='' then return end
    local payload = json.encode({username='LRRP Stables',embeds={{title=title,description=description,color=10181046,footer={text='LRRP_Stables v1.0'}}}})
    PerformHttpRequest(url,function() end,'POST',payload,{['Content-Type']='application/json'})
end

local function audit(src,action,targetType,targetId,details)
    local identifier,charId = identity(src)
    DB.insert([[INSERT INTO lrrp_stable_audit_logs(source_id,player_name,identifier,charidentifier,action,target_type,target_id,details)
      VALUES(?,?,?,?,?,?,?,?)]],{tonumber(src) or 0,playerNameSafe(src),identifier or 'console',charId or 0,tostring(action),tostring(targetType or ''),tonumber(targetId),LRRP.SafeJsonEncode(details or {})})
    webhook(('LRRP Stables • %s'):format(action),('Jogador: **%s** (`%s`)\nAlvo: `%s #%s`'):format(playerNameSafe(src),src,targetType or '-',targetId or '-'))
end

local function ranchAccess(src,ranchId,minRole)
    local identifier,charId = identity(src); if not identifier then return false end
    local r=DB.single('SELECT * FROM lrrp_ranches WHERE id=?',{tonumber(ranchId)}); if not r then return false end
    if r.identifier==identifier and tonumber(r.charidentifier)==tonumber(charId) then return true,'owner',r end
    local m=DB.single("SELECT role FROM lrrp_ranch_members WHERE ranch_id=? AND identifier=? AND charidentifier=? AND status='active'",{r.id,identifier,charId})
    if not m then return false,nil,r end
    local rank={guest=1,worker=2,manager=3,owner=4}; local need=rank[minRole or 'guest'] or 1
    return (rank[m.role] or 0)>=need,m.role,r
end

local function findRanchForPlayer(src)
    local r=ranchOf(src); if r then return r,'owner' end
    local identifier,charId=identity(src); if not identifier then return nil end
    local row=DB.single([[SELECT r.*,m.role member_role FROM lrrp_ranch_members m JOIN lrrp_ranches r ON r.id=m.ranch_id
      WHERE m.identifier=? AND m.charidentifier=? AND m.status='active' ORDER BY FIELD(m.role,'manager','worker','guest') LIMIT 1]],{identifier,charId})
    return row,row and row.member_role or nil
end

local function inventoryCount(src,item)
    if GetResourceState('vorp_inventory')~='started' then return 0 end
    local ok,res=pcall(function() return exports.vorp_inventory:getItem(src,item) end)
    return ok and res and (tonumber(res.count) or 0) or 0
end
local function inventorySub(src,item,amount)
    amount=math.max(1,math.floor(tonumber(amount) or 1))
    if inventoryCount(src,item)<amount then return false end
    local ok,res=pcall(function() return exports.vorp_inventory:subItem(src,item,amount) end)
    return ok and res~=false
end

local function v10Data(src)
    local r,role=findRanchForPlayer(src)
    local members,maintenance,logs={},{},{}
    if r then
        local allowed=r.identifier==select(1,identity(src)) or ranchAccess(src,r.id,'worker')
        if allowed then
            members=DB.query("SELECT id,player_name,role,status,created_at FROM lrrp_ranch_members WHERE ranch_id=? ORDER BY FIELD(role,'manager','worker','guest'),id",{r.id}) or {}
            maintenance=DB.query('SELECT id,structure_key,label,durability,max_durability,x,y,z,heading FROM lrrp_ranch_structures WHERE ranch_id=? ORDER BY id DESC',{r.id}) or {}
        end
    end
    if IsPlayerAceAllowed(src,Config.Admin.ace) then
        logs=DB.query('SELECT id,source_id,player_name,action,target_type,target_id,created_at FROM lrrp_stable_audit_logs ORDER BY id DESC LIMIT 30',{}) or {}
    end
    TriggerClientEvent('lrrp_stables:v10DataClient',src,{ranch=r,role=role,members=members,structures=maintenance,logs=logs,disciplines=Config.Release.disciplines})
end

RegisterNetEvent('lrrp_stables:v10Data',function() v10Data(source) end)

RegisterNetEvent('lrrp_stables:ranchInvite',function(target,role)
    local src=source; local r=ranchOf(src); if not r then return VORPAdapter.notify(src,'Você precisa ser dono de um rancho.') end
    target=tonumber(target); role=tostring(role or 'worker')
    if not target or not GetPlayerName(target) then return VORPAdapter.notify(src,'Jogador não encontrado.') end
    if role~='manager' and role~='worker' and role~='guest' then role='worker' end
    local tid,tcid=identity(target); if not tid then return end
    DB.insert([[INSERT INTO lrrp_ranch_members(ranch_id,identifier,charidentifier,player_name,role,status)
      VALUES(?,?,?,?,?,'active') ON DUPLICATE KEY UPDATE player_name=VALUES(player_name),role=VALUES(role),status='active']],{r.id,tid,tcid,playerNameSafe(target),role})
    audit(src,'ranch_invite','ranch',r.id,{target=target,role=role})
    VORPAdapter.notify(src,'Permissão adicionada ao rancho.'); VORPAdapter.notify(target,('Você recebeu acesso ao rancho %s como %s.'):format(r.name,role)); v10Data(src); v10Data(target)
end)

RegisterNetEvent('lrrp_stables:ranchRemoveMember',function(memberId)
    local src=source; local r=ranchOf(src); if not r then return end
    local row=DB.single('SELECT * FROM lrrp_ranch_members WHERE id=? AND ranch_id=?',{tonumber(memberId),r.id}); if not row then return end
    DB.update("UPDATE lrrp_ranch_members SET status='revoked' WHERE id=?",{row.id})
    audit(src,'ranch_remove_member','ranch',r.id,{member=row.player_name,role=row.role}); VORPAdapter.notify(src,'Acesso removido.'); v10Data(src)
end)

RegisterNetEvent('lrrp_stables:confirmStructurePlacementV10',function(kind,pos)
    local src=source; local r,role=findRanchForPlayer(src); if not r then return VORPAdapter.notify(src,'Você não tem acesso a um rancho.') end
    local ok=r.identifier==select(1,identity(src)) or ranchAccess(src,r.id,'manager'); if not ok then return VORPAdapter.notify(src,'Apenas proprietário/gerente pode construir.') end
    local def=Config.RanchBuilding.structures[tostring(kind or '')]; if not def then return end
    local x,y,z,h=tonumber(pos and pos.x),tonumber(pos and pos.y),tonumber(pos and pos.z),tonumber(pos and pos.heading) or 0
    if not x or not y or not z then return end
    local dx,dy,dz=x-r.x,y-r.y,z-r.z; if math.sqrt(dx*dx+dy*dy+dz*dz)>(Config.RanchBuilding.maxBuildDistance or 45.0) then return VORPAdapter.notify(src,'Posição fora da área do rancho.') end
    local count=tonumber((DB.single('SELECT COUNT(*) total FROM lrrp_ranch_structures WHERE ranch_id=? AND structure_key=?',{r.id,kind}) or {}).total) or 0
    if def.max and count>=def.max then return VORPAdapter.notify(src,'Limite desta estrutura atingido.') end
    if not VORPAdapter.removeCurrency(src,0,def.price or 0) then return VORPAdapter.notify(src,'Dinheiro insuficiente.') end
    local durability=Config.Release.structureMaintenance.maxDurability or 100
    local sid=DB.insert('INSERT INTO lrrp_ranch_structures(ranch_id,structure_key,label,x,y,z,heading,durability,max_durability,last_maintained_at) VALUES(?,?,?,?,?,?,?,?,?,NOW())',{r.id,kind,def.label,x,y,z,h,durability,durability})
    if kind=='pasture_fence' and (def.capacityBonus or 0)>0 then DB.update('UPDATE lrrp_ranches SET pasture_capacity=pasture_capacity+? WHERE id=?',{def.capacityBonus,r.id}) end
    audit(src,'structure_build','structure',sid,{kind=kind,price=def.price,x=x,y=y,z=z}); VORPAdapter.notify(src,'Estrutura construída e salva.'); TriggerClientEvent('lrrp_stables:refreshV9',src); v10Data(src)
end)

RegisterNetEvent('lrrp_stables:repairStructureV10',function(structureId)
    local src=source; local row=DB.single([[SELECT s.*,r.identifier owner_identifier,r.charidentifier owner_charidentifier FROM lrrp_ranch_structures s JOIN lrrp_ranches r ON r.id=s.ranch_id WHERE s.id=?]],{tonumber(structureId)}); if not row then return end
    local ok=ranchAccess(src,row.ranch_id,'worker'); if not ok then return VORPAdapter.notify(src,'Sem permissão para manutenção.') end
    local missing=math.max(0,(tonumber(row.max_durability) or 100)-(tonumber(row.durability) or 0)); if missing<=0 then return VORPAdapter.notify(src,'Estrutura já está em ótimo estado.') end
    local price=math.max(1,math.ceil(missing*(Config.Release.structureMaintenance.pricePerPoint or 2)))
    if not VORPAdapter.removeCurrency(src,0,price) then return VORPAdapter.notify(src,'Dinheiro insuficiente para manutenção.') end
    DB.update('UPDATE lrrp_ranch_structures SET durability=max_durability,last_maintained_at=NOW() WHERE id=?',{row.id})
    audit(src,'structure_repair','structure',row.id,{price=price}); VORPAdapter.notify(src,('Estrutura reparada por $%d.'):format(price)); v10Data(src)
end)

RegisterNetEvent('lrrp_stables:saveWildNameV10',function(token,name)
    local src=source; name=tostring(name or ''):gsub('[%c<>]',''):sub(1,32); if #name<2 then name='Cavalo Selvagem' end
    TriggerEvent('lrrp_stables:v10CompleteWildHorseInternal',src,token,name)
end)

AddEventHandler('lrrp_stables:v10CompleteWildHorseInternal',function(src,token,name)
    local pending=LRRPV9Server and LRRPV9Server.tameTokens and LRRPV9Server.tameTokens[src]
    if not pending or pending.token~=token or pending.expires<os.time() then return VORPAdapter.notify(src,'Tentativa de doma expirada.') end
    LRRPV9Server.tameTokens[src]=nil
    local id,cid=identity(src); if not id then return end
    local count=tonumber((DB.single('SELECT COUNT(*) total FROM lrrp_horses WHERE identifier=? AND charidentifier=?',{id,cid}) or {}).total) or 0
    if count>=Config.MaxHorses then return VORPAdapter.notify(src,'Você atingiu o limite de cavalos.') end
    local sex=math.random(1,2)==1 and 'male' or 'female'
    local primary=count==0 and 1 or 0
    local hid=DB.insert([[INSERT INTO lrrp_horses(identifier,charidentifier,name,model,is_primary,price,purchase_currency,health,stamina,hunger,thirst,cleanliness,xp,bonding,training,accessories,weapon_storage,upgrades,sex,birth_at,genetics,health_state,life_stage,rarity,mutation,death_state,wild_origin,tamed_at,transport_state,disciplines,horseshoe_durability)
      VALUES(?,?,?,?,?,0,0,90,90,70,70,55,0,1,0,'{}','{}','{}',?,NOW(),'{}','{}','adult','common','{}','alive',1,NOW(),'none','{}',100)]],{id,cid,name,pending.model,primary,sex})

    if not hid then
        return VORPAdapter.notify(src,'Não foi possível salvar o cavalo domesticado.')
    end

    audit(src,'wild_horse_tamed','horse',hid,{model=pending.model,name=name,sex=sex})
    VORPAdapter.notify(src,('🐎 Doma concluída! %s (%s) foi registrado no estábulo.'):format(
        name,sex=='male' and 'macho' or 'fêmea'
    ))
    print(('[estabulo_VT] DOMA OK | src=%s id=%s nome=%s modelo=%s sexo=%s'):format(
        tostring(src),tostring(hid),tostring(name),tostring(pending.model),tostring(sex)
    ))
    TriggerClientEvent('lrrp_stables:refreshV6',src)
    v10Data(src)
end)

RegisterNetEvent('lrrp_stables:requestDisciplineTrainingV10',function(horseId,discipline)
    local src=source; local h=ownedHorse(src,horseId); local def=Config.Release.disciplines[tostring(discipline or '')]; if not h or not def then return end
    local token=('%s:%s:%s'):format(src,os.time(),math.random(100000,999999)); LRRPV10.trainingTokens[src]={token=token,horseId=h.id,discipline=discipline,expires=os.time()+120}
    TriggerClientEvent('lrrp_stables:startDisciplineTrainingV10',src,{horseId=h.id,discipline=discipline,rounds=6,token=token})
end)

RegisterNetEvent('lrrp_stables:completeDisciplineTrainingV10',function(horseId,discipline,score,token)
    local src=source; local pending=LRRPV10.trainingTokens[src]; if not pending or pending.token~=token or pending.expires<os.time() or tonumber(pending.horseId)~=tonumber(horseId) or pending.discipline~=discipline then return VORPAdapter.notify(src,'Sessão de treino inválida ou expirada.') end
    LRRPV10.trainingTokens[src]=nil
    local h=ownedHorse(src,horseId); if not h then return end
    local def=Config.Release.disciplines[tostring(discipline or '')]; if not def then return end
    score=math.max(0,math.min(100,tonumber(score) or 0)); if score<(def.minScore or 50) then return VORPAdapter.notify(src,'Treino não atingiu a pontuação mínima.') end
    local d=LRRP.SafeJsonDecode(h.disciplines); local old=tonumber(d[discipline] or 0); d[discipline]=math.min(def.maxLevel or 10,old+1)
    DB.update('UPDATE lrrp_horses SET disciplines=?,training=LEAST(100,training+?),xp=xp+? WHERE id=?',{LRRP.SafeJsonEncode(d),def.trainingGain or 2,def.xp or 15,h.id})
    audit(src,'discipline_training','horse',h.id,{discipline=discipline,score=score,level=d[discipline]}); VORPAdapter.notify(src,('Treino de %s concluído. Nível %d.'):format(def.label,d[discipline])); TriggerClientEvent('lrrp_stables:refreshV6',src); v10Data(src)
end)

RegisterNetEvent('lrrp_stables:requestVetDiagnosisV10',function(horseId)
    local src=source; if not Config.HealthSystem.vetJobs[VORPAdapter.job(src) or ''] then return VORPAdapter.notify(src,'Você não é veterinário.') end
    local h=ownedHorse(src,horseId); if not h then return end
    local token=('%s:%s:%s'):format(src,os.time(),math.random(100000,999999)); LRRPV10.vetTokens[src]={token=token,horseId=h.id,expires=os.time()+120}
    TriggerClientEvent('lrrp_stables:startVetDiagnosisV10',src,{horseId=h.id,token=token})
end)

RegisterNetEvent('lrrp_stables:vetDiagnosisCompleteV10',function(horseId,score,token)
    local src=source; local pending=LRRPV10.vetTokens[src]; if not pending or pending.token~=token or pending.expires<os.time() or tonumber(pending.horseId)~=tonumber(horseId) then return VORPAdapter.notify(src,'Sessão veterinária inválida ou expirada.') end
    LRRPV10.vetTokens[src]=nil
    if not Config.HealthSystem.vetJobs[VORPAdapter.job(src) or ''] then return VORPAdapter.notify(src,'Você não é veterinário.') end
    local h=ownedHorse(src,horseId); if not h then return end
    if tonumber(score or 0)<60 then return VORPAdapter.notify(src,'Diagnóstico inconclusivo.') end
    if not inventorySub(src,Config.ProfessionalItems.vet.item,Config.ProfessionalItems.vet.amount or 1) then return VORPAdapter.notify(src,'Falta '..Config.ProfessionalItems.vet.item..'.') end
    DB.update("UPDATE lrrp_horses SET health=LEAST(100,health+45),stamina=LEAST(100,stamina+30),health_state='{}' WHERE id=?",{h.id})
    audit(src,'vet_diagnosis_treatment','horse',h.id,{score=score}); VORPAdapter.notify(src,'Diagnóstico e tratamento concluídos.'); TriggerClientEvent('lrrp_stables:refreshV6',src)
end)

RegisterNetEvent('lrrp_stables:horseShoeWearV10',function(horseId,meters)
    local src=source; local now=os.time(); local last=LRRPV10.wearThrottle[src] or 0; if now-last<20 then return end; LRRPV10.wearThrottle[src]=now
    local h=ownedHorse(src,horseId); if not h then return end
    meters=math.max(0,math.min(Config.Release.horseshoe.maxMetersPerTick or 600,tonumber(meters) or 0)); if meters<50 then return end
    local loss=math.max(1,math.floor(meters/(Config.Release.horseshoe.metersPerDurability or 250)))
    DB.update('UPDATE lrrp_horses SET horseshoe_durability=GREATEST(0,horseshoe_durability-?) WHERE id=?',{loss,h.id})
end)

RegisterNetEvent('lrrp_stables:adminV10Action',function(action,targetId,value)
    local src=source; if not IsPlayerAceAllowed(src,Config.Admin.ace) then return end
    action=tostring(action or ''); targetId=tonumber(targetId); value=tonumber(value)
    if action=='setShoeDurability' and targetId then DB.update('UPDATE lrrp_horses SET horseshoe_durability=? WHERE id=?',{math.max(0,math.min(100,value or 100)),targetId})
    elseif action=='repairAllStructures' then DB.update('UPDATE lrrp_ranch_structures SET durability=max_durability,last_maintained_at=NOW()',{})
    elseif action=='clearOldLogs' then DB.update('DELETE FROM lrrp_stable_audit_logs WHERE created_at<DATE_SUB(NOW(),INTERVAL ? DAY)',{Config.Release.auditRetentionDays or 90})
    else return end
    audit(src,'admin_v10_'..action,targetId and 'horse' or 'global',targetId,{value=value}); VORPAdapter.notify(src,'Ação administrativa executada.'); v10Data(src)
end)

CreateThread(function()
    Wait(30000)
    while true do
        local cfg=Config.Release.structureMaintenance
        if cfg.enabled then
            DB.update('UPDATE lrrp_ranch_structures SET durability=GREATEST(0,durability-?) WHERE durability>0',{cfg.decayPerCycle or 1})
        end
        Wait((cfg.cycleHours or 24)*3600000)
    end
end)

AddEventHandler('playerDropped',function() LRRPV10.wearThrottle[source]=nil; LRRPV10.trainingTokens[source]=nil; LRRPV10.vetTokens[source]=nil end)

exports('HasRanchAccess',function(src,ranchId,role) return ranchAccess(tonumber(src),tonumber(ranchId),role or 'guest') end)
exports('GetRanchForPlayer',function(src) return findRanchForPlayer(tonumber(src)) end)

-- Auditoria passiva dos fluxos críticos legados. Registra a solicitação; a validação/mutação continua no módulo original.
AddEventHandler('lrrp_stables:sell',function(horseId) audit(source,'sell_requested','horse',tonumber(horseId),{}) end)
AddEventHandler('lrrp_stables:transfer',function(horseId,target) audit(source,'transfer_requested','horse',tonumber(horseId),{target=tonumber(target)}) end)
AddEventHandler('lrrp_stables:createAuction',function(horseId,price,currency,duration) audit(source,'auction_requested','horse',tonumber(horseId),{price=price,currency=currency,duration=duration}) end)
AddEventHandler('lrrp_stables:insureHorse',function(horseId) audit(source,'insurance_requested','horse',tonumber(horseId),{}) end)
AddEventHandler('lrrp_stables:createRaceRoom',function(trackKey,horseId) audit(source,'race_room_requested','horse',tonumber(horseId),{track=trackKey}) end)
