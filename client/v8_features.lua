LRRPV8={data={ranch=nil,workers={},horses={},raceRooms={},isJockey=false,isAdmin=false},pasture={},race=nil}
RegisterNetEvent('lrrp_stables:v8DataClient',function(data)
    LRRPV8.data=data or LRRPV8.data
    if StableUI and StableUI.open then SendNUIMessage({action='v8Data',data=LRRPV8.data}) end
end)
RegisterNetEvent('lrrp_stables:refreshV8',function() TriggerServerEvent('lrrp_stables:v8Data') end)

local function deletePasture()
    for _,ped in ipairs(LRRPV8.pasture) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    LRRPV8.pasture={}
end
local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash); local deadline=GetGameTimer()+8000
    while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(20) end
    return HasModelLoaded(hash)
end
RegisterNetEvent('lrrp_stables:pastureClient',function(data)
    deletePasture(); if type(data)~='table' or not data.ranch then return end
    local r=data.ranch; local horses=data.horses or {}; local workers=data.workers or {}; local radius=Config.RanchAutomation.pastureRadius or 18.0
    for i,h in ipairs(horses) do
        local hash=joaat(h.model); if loadModel(hash) then
            local a=(i/#horses)*math.pi*2; local x=r.x+math.cos(a)*radius; local y=r.y+math.sin(a)*radius
            local ped=CreatePed(hash,x,y,r.z+0.3,math.deg(a)+90.0,false,false,false,false)
            if ped and ped~=0 then
                SetEntityAsMissionEntity(ped,true,true); Citizen.InvokeNative(0x283978A15512B2FE,ped,true); SetBlockingOfNonTemporaryEvents(ped,true)
                TaskWanderStandard(ped,7.0,10); table.insert(LRRPV8.pasture,ped)
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
    local whash=joaat(Config.RanchAutomation.workerModel)
    if #workers>0 and loadModel(whash) then
        for i,w in ipairs(workers) do
            local ped=CreatePed(whash,r.x+(i*1.6),r.y+2.0,r.z+0.2,180.0,false,false,false,false)
            if ped and ped~=0 then SetEntityAsMissionEntity(ped,true,true); SetBlockingOfNonTemporaryEvents(ped,true); TaskWanderStandard(ped,3.0,10); table.insert(LRRPV8.pasture,ped) end
        end
        SetModelAsNoLongerNeeded(whash)
    end
    TriggerEvent('lrrp_stables:notify',('%d cavalo(s) soltos no pasto local.'):format(#LRRPV8.pasture))
end)

local function trackByKey(key) for _,t in ipairs((Config.Racing and Config.Racing.tracks) or {}) do if t.key==key then return t end end end
RegisterNetEvent('lrrp_stables:startMultiplayerRaceClient',function(data)
    local t=trackByKey(data.trackKey); if not t then return end
    local mount=GetMount(PlayerPedId()); if not mount or mount==0 then return TriggerEvent('lrrp_stables:notify','Monte no cavalo inscrito e vá para a largada.') end
    local p=GetEntityCoords(PlayerPedId()); if #(p-t.start)>45.0 then return TriggerEvent('lrrp_stables:notify','Você está longe da largada; inscrição mantida, mas não largou.') end
    local countdown=tonumber(data.countdown) or 5
    CreateThread(function()
        for n=countdown,1,-1 do TriggerEvent('vorp:TipBottom',('Largada em %d...'):format(n),1000); Wait(1000) end
        TriggerEvent('vorp:TipBottom','VAI!',1500); LRRPV8.race={eventId=data.eventId,track=t,start=GetGameTimer()}
    end)
end)
CreateThread(function()
    while true do
        local sleep=1000
        if LRRPV8.race then
            sleep=0; local p=GetEntityCoords(PlayerPedId()); local f=LRRPV8.race.track.finish
            Citizen.InvokeNative(0x2A32FAA57B937173,0x6903B113,f.x,f.y,f.z-0.8,0,0,0,0,0,0,1.3,1.3,1.3,255,220,120,190,false,false,2,false,nil,nil,false)
            if #(p-f)<5.0 then local ms=GetGameTimer()-LRRPV8.race.start; TriggerServerEvent('lrrp_stables:finishMultiplayerRace',LRRPV8.race.eventId,ms); TriggerEvent('lrrp_stables:notify',('Tempo multiplayer: %.2fs'):format(ms/1000)); LRRPV8.race=nil end
        end
        Wait(sleep)
    end
end)

RegisterNUICallback('stockRanchFeed',function(data,cb) TriggerServerEvent('lrrp_stables:stockRanchFeed',tonumber(data.amount)); cb({ok=true}) end)
RegisterNUICallback('hireRanchWorker',function(data,cb) TriggerServerEvent('lrrp_stables:hireRanchWorker',tostring(data.name or 'Tratador')); cb({ok=true}) end)
RegisterNUICallback('fireRanchWorker',function(data,cb) TriggerServerEvent('lrrp_stables:fireRanchWorker',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('showPasture',function(_,cb) StableUI.closeMenu(); TriggerServerEvent('lrrp_stables:showPasture'); cb({ok=true}) end)
RegisterNUICallback('createRaceRoom',function(data,cb) TriggerServerEvent('lrrp_stables:createRaceRoom',tostring(data.key),tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('joinRaceRoom',function(data,cb) TriggerServerEvent('lrrp_stables:joinRaceRoom',tonumber(data.eventId),tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('startRaceRoom',function(data,cb) StableUI.closeMenu(); TriggerServerEvent('lrrp_stables:startRaceRoom',tonumber(data.eventId)); cb({ok=true}) end)
RegisterNUICallback('betRace',function(data,cb) TriggerServerEvent('lrrp_stables:betRace',tonumber(data.eventId),tonumber(data.entryId),tonumber(data.amount)); cb({ok=true}) end)
RegisterNUICallback('adminHorse',function(data,cb) TriggerServerEvent('lrrp_stables:adminHorse',tonumber(data.id),tostring(data.action),data.value); cb({ok=true}) end)

AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then deletePasture(); for _,a in ipairs(AuctionNPCs or {}) do if DoesEntityExist(a.ped) then DeleteEntity(a.ped) end end end end)

RegisterNUICallback('payRanchDebt',function(_,cb) TriggerServerEvent('lrrp_stables:payRanchDebt'); cb({ok=true}) end)

local AuctionNPCs={}
CreateThread(function()
    if not Config.LiveAuction.enabled then return end
    Wait(2500)
    local hash=joaat(Config.LiveAuction.npcModel)
    if not loadModel(hash) then return end
    for i,stable in ipairs(Config.Stables) do
        local base=stable.npc or vector4(stable.coords.x,stable.coords.y,stable.coords.z,0.0)
        local ped=CreatePed(hash,base.x+2.2,base.y+1.3,base.z,base.w or 0.0,false,false,false,false)
        if ped and ped~=0 then SetEntityAsMissionEntity(ped,true,true); FreezeEntityPosition(ped,true); SetEntityInvincible(ped,true); SetBlockingOfNonTemporaryEvents(ped,true); table.insert(AuctionNPCs,{ped=ped,stableIndex=i}) end
    end
    SetModelAsNoLongerNeeded(hash)
    while true do
        local sleep=1000; local pp=PlayerPedId(); local pc=GetEntityCoords(pp)
        for _,a in ipairs(AuctionNPCs) do if DoesEntityExist(a.ped) then local d=#(pc-GetEntityCoords(a.ped)); if d<8.0 then sleep=0; if d<Config.LiveAuction.interactionDistance then TriggerEvent('vorp:TipBottom','Pressione [E] para falar com o Leiloeiro',800); if IsControlJustReleased(0,Config.UI.openControl) and not StableUI.open then StableUI.openMenu(a.stableIndex); Wait(100); SendNUIMessage({action='openTab',tab='auction'}) end end end end end
        Wait(sleep)
    end
end)

RegisterNetEvent('lrrp_stables:breedingSceneClient',function(data)
    if StableUI and StableUI.open then StableUI.closeMenu() end
    local center=GetEntityCoords(PlayerPedId())
    local models={data and data.motherModel,data and data.fatherModel}; local scene={}
    for i,m in ipairs(models) do
        if m then local hash=joaat(m); if loadModel(hash) then local off=i==1 and -2.0 or 2.0; local ped=CreatePed(hash,center.x+off,center.y+4.0,center.z, i==1 and 90.0 or 270.0,false,false,false,false); if ped and ped~=0 then SetEntityAsMissionEntity(ped,true,true); SetBlockingOfNonTemporaryEvents(ped,true); TaskStandStill(ped,9000); table.insert(scene,ped) end; SetModelAsNoLongerNeeded(hash) end end
    end
    TriggerEvent('vorp:TipBottom','Criação registrada no rancho...',5000); Wait(7000)
    for _,ped in ipairs(scene) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
end)
