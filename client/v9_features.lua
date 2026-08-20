LRRPV9={data={},wagon=nil,wildHorse=nil,taming=nil,advancedRace=nil,spectating=false,spectatorCam=nil,structures={}}

local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash); local untilAt=GetGameTimer()+8000
    while not HasModelLoaded(hash) and GetGameTimer()<untilAt do Wait(20) end
    return HasModelLoaded(hash)
end
local function deleteEntitySafe(e) if e and e~=0 and DoesEntityExist(e) then DeleteEntity(e) end end

local function clearStructures()
    for _,obj in ipairs(LRRPV9.structures) do deleteEntitySafe(obj) end
    LRRPV9.structures={}
end
local function spawnStructures(rows)
    clearStructures()
    for _,row in ipairs(rows or {}) do
        local def=Config.RanchBuilding.structures[row.structure_key]
        if def and def.prop then
            local hash=joaat(def.prop)
            if loadModel(hash) then
                local obj=CreateObject(hash,tonumber(row.x),tonumber(row.y),tonumber(row.z),false,false,false,false,false)
                if obj and obj~=0 then SetEntityAsMissionEntity(obj,true,true); SetEntityHeading(obj,tonumber(row.heading) or 0.0); FreezeEntityPosition(obj,true); table.insert(LRRPV9.structures,obj) end
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
end

RegisterNetEvent('lrrp_stables:v9DataClient',function(data)
    LRRPV9.data=data or {}
    spawnStructures(LRRPV9.data.structures or {})
    if StableUI and StableUI.open then SendNUIMessage({action='v9Data',data=LRRPV9.data}) end
end)
RegisterNetEvent('lrrp_stables:refreshV9',function() TriggerServerEvent('lrrp_stables:v9Data') end)

CreateThread(function() Wait(8000); TriggerServerEvent('lrrp_stables:v9Data') end)

RegisterNetEvent('lrrp_stables:spawnTransportWagonClient',function(data)
    deleteEntitySafe(LRRPV9.wagon); LRRPV9.wagon=nil
    local hash=joaat(Config.HorseTransport.wagonModel)
    if not loadModel(hash) then return TriggerEvent('lrrp_stables:notify','Modelo da carroça de transporte inválido.') end
    local p=GetEntityCoords(PlayerPedId()); local h=GetEntityHeading(PlayerPedId())
    local wagon=CreateVehicle(hash,p.x+4.0,p.y+2.0,p.z,h,false,false,false,false)
    if wagon and wagon~=0 then SetEntityAsMissionEntity(wagon,true,true); LRRPV9.wagon=wagon; TriggerEvent('lrrp_stables:notify','Carroça de transporte preparada. Use o menu para descarregar.') end
    SetModelAsNoLongerNeeded(hash)
end)
RegisterNetEvent('lrrp_stables:removeTransportWagonClient',function() deleteEntitySafe(LRRPV9.wagon); LRRPV9.wagon=nil end)

local function nearestWildZone()
    local p=GetEntityCoords(PlayerPedId())
    local best=nil
    local dist=99999.0
    for _,z in ipairs(Config.WildHorses.zones or {}) do
        local d=#(p-z.coords)
        if d<dist then best=z; dist=d end
    end
    return best,dist
end

local function spawnWildHorse(zone)
    deleteEntitySafe(LRRPV9.wildHorse)
    LRRPV9.wildHorse=nil
    LRRPV9.wildModel=nil

    if not zone or not Config.WildHorses.models or #Config.WildHorses.models==0 then return end

    local model=Config.WildHorses.models[math.random(1,#Config.WildHorses.models)]
    local hash=joaat(model)
    if not loadModel(hash) then
        return TriggerEvent('lrrp_stables:notify','Não foi possível carregar o cavalo selvagem.')
    end

    -- Spawn relativamente perto do centro da zona para facilitar o teste,
    -- mas ainda de forma aleatória.
    local a=math.random()*math.pi*2
    local maxRadius=math.max(20,math.floor((zone.radius or 80)*0.55))
    local r=math.random(15,maxRadius)
    local x=zone.coords.x+math.cos(a)*r
    local y=zone.coords.y+math.sin(a)*r
    local z=zone.coords.z+1.0

    local ped=CreatePed(hash,x,y,z,math.random(0,359)+0.0,false,false,false,false)
    if (not ped) or ped==0 then
        ped=Citizen.InvokeNative(0xD49F9B0955C367DE,hash,x,y,z,0.0,false,false,false,false)
    end

    if ped and ped~=0 and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped,true,true)
        SetEntityVisible(ped,true)
        SetEntityAlpha(ped,255,false)
        pcall(function() PlaceEntityOnGroundProperly(ped,true) end)
        pcall(function() Citizen.InvokeNative(0x283978A15512B2FE,ped,true) end)
        SetBlockingOfNonTemporaryEvents(ped,false)
        TaskWanderStandard(ped,6.0,10)

        LRRPV9.wildHorse=ped
        LRRPV9.wildModel=model

        local hc=GetEntityCoords(ped)
        print(('[estabulo_VT] SELVAGEM SPAWN | zona=%s modelo=%s entity=%s coords=%.2f %.2f %.2f'):format(
            tostring(zone.label),tostring(model),tostring(ped),hc.x,hc.y,hc.z
        ))
        TriggerEvent('lrrp_stables:notify',('🐎 Um cavalo selvagem apareceu em %s.'):format(tostring(zone.label)))
    end

    SetModelAsNoLongerNeeded(hash)
end

RegisterCommand('cavaloselvagem',function()
    local z,d=nearestWildZone()
    if not z or d>(z.radius or 80) then
        return TriggerEvent('lrrp_stables:notify','Você não está em uma zona de cavalos selvagens.')
    end
    spawnWildHorse(z)
end,false)

RegisterCommand('zonaselvagem',function()
    local z,d=nearestWildZone()
    if not z then return end
    TriggerEvent('lrrp_stables:notify',('Zona mais próxima: %s • distância %.0fm • raio %.0fm'):format(
        tostring(z.label),d,tonumber(z.radius) or 0
    ))
end,false)

CreateThread(function()
    while true do
        local sleep=1000

        if Config.WildHorses.enabled and not LRRPV9.taming then
            local z,d=nearestWildZone()

            if z and d<(z.radius or 80) then
                if not LRRPV9.wildHorse or not DoesEntityExist(LRRPV9.wildHorse) then
                    spawnWildHorse(z)
                end

                if LRRPV9.wildHorse and DoesEntityExist(LRRPV9.wildHorse) then
                    local p=GetEntityCoords(PlayerPedId())
                    local hp=GetEntityCoords(LRRPV9.wildHorse)
                    local hd=#(p-hp)

                    if hd<=(Config.WildHorses.interactionDistance or 5.0) then
                        sleep=0
                        TriggerEvent('vorp:TipBottom','[G] Tentar domar cavalo selvagem',120)

                        local control=Config.WildHorses.interactionControl or 0x760A9C6F
                        if IsControlJustReleased(0,control) or IsDisabledControlJustReleased(0,control) then
                            ClearPedTasks(LRRPV9.wildHorse)
                            SetBlockingOfNonTemporaryEvents(LRRPV9.wildHorse,true)
                            TaskStandStill(LRRPV9.wildHorse,16000)
                            TriggerServerEvent('lrrp_stables:requestWildTame',LRRPV9.wildModel)
                            Wait(700)
                        end
                    end
                end
            else
                deleteEntitySafe(LRRPV9.wildHorse)
                LRRPV9.wildHorse=nil
                LRRPV9.wildModel=nil
            end
        end

        Wait(sleep)
    end
end)

local tameControls={
    {name='W',hash=0x8FD015D8},
    {name='A',hash=0x7065027D},
    {name='S',hash=0xD27782E3},
    {name='D',hash=0xB4E465B4},
    {name='SHIFT',hash=0x8FFC75D6}
}

RegisterNetEvent('lrrp_stables:startTamingMinigameClient',function(data)
    if LRRPV9.taming then return end
    if not data or not data.token then return end

    LRRPV9.taming={token=data.token,model=data.model}
    local steps=math.max(3,tonumber(data.steps) or 6)

    CreateThread(function()
        local horse=LRRPV9.wildHorse
        if not horse or not DoesEntityExist(horse) then
            LRRPV9.taming=nil
            return TriggerEvent('lrrp_stables:notify','O cavalo selvagem não está mais disponível.')
        end

        if Config.Release and Config.Release.mountedWildTaming then
            ClearPedTasks(horse)
            SetBlockingOfNonTemporaryEvents(horse,true)
            TaskStandStill(horse,Config.WildHorses.mountTimeoutMs or 15000)

            local untilMount=GetGameTimer()+(Config.WildHorses.mountTimeoutMs or 15000)
            while GetGameTimer()<untilMount and GetMount(PlayerPedId())~=horse do
                Wait(0)
                TriggerEvent('vorp:TipBottom','🐎 Monte no cavalo selvagem para iniciar a doma',120)
            end

            if GetMount(PlayerPedId())~=horse then
                SetBlockingOfNonTemporaryEvents(horse,false)
                TaskSmartFleePed(horse,PlayerPedId(),80.0,-1,2.0,0)
                LRRPV9.taming=nil
                return TriggerEvent('lrrp_stables:notify','O cavalo escapou antes de você conseguir montar.')
            end
        end

        TriggerEvent('lrrp_stables:notify','Doma iniciada. Acerte a sequência de comandos.')

        for i=1,steps do
            local control=tameControls[math.random(1,#tameControls)]
            local ok=false
            local untilAt=GetGameTimer()+(Config.WildHorses.inputTimeoutMs or 3500)

            while GetGameTimer()<untilAt do
                Wait(0)
                local text=('DOMA %d/%d  |  PRESSIONE [%s]'):format(i,steps,control.name)
                TriggerEvent('vorp:TipBottom',text,120)

                SetTextScale(0.55,0.55)
                SetTextColor(255,255,255,255)
                SetTextCentre(true)
                DisplayText(CreateVarString(10,'LITERAL_STRING',text),0.50,0.80)

                if IsControlJustPressed(0,control.hash) or IsControlJustReleased(0,control.hash) then
                    ok=true
                    break
                end
            end

            if not ok then
                if DoesEntityExist(horse) then
                    SetBlockingOfNonTemporaryEvents(horse,false)
                    TaskSmartFleePed(horse,PlayerPedId(),100.0,-1,2.5,0)
                end
                LRRPV9.taming=nil
                return TriggerEvent('lrrp_stables:notify','❌ A doma falhou e o cavalo escapou.')
            end

            TriggerEvent('lrrp_stables:notify','✅ Movimento correto.')
            Wait(250)
        end

        -- Desmonta antes de remover o PED visual e abrir a janela de nome.
        if GetMount(PlayerPedId())==horse then
            TaskDismountAnimal(PlayerPedId(),0,0,0,0,0)
            Wait(800)
        end

        TriggerEvent('lrrp_stables:requestWildHorseNameV10',{
            token=data.token,
            model=data.model
        })

        deleteEntitySafe(LRRPV9.wildHorse)
        LRRPV9.wildHorse=nil
        LRRPV9.wildModel=nil
        LRRPV9.taming=nil
    end)
end)

RegisterNetEvent('lrrp_stables:startAdvancedRaceClient',function(data)
    local t=nil; for _,r in ipairs(Config.AdvancedRacing.tracks or {}) do if r.key==data.trackKey then t=r break end end
    if not t then return end
    local mount=GetMount(PlayerPedId()); if not mount or mount==0 then return TriggerEvent('lrrp_stables:notify','Monte no cavalo inscrito.') end
    CreateThread(function()
        for n=(tonumber(data.countdown) or 5),1,-1 do TriggerEvent('vorp:TipBottom',('Largada em %d...'):format(n),1000); Wait(1000) end
        TriggerEvent('vorp:TipBottom','VAI!',1200); LRRPV9.advancedRace={eventId=data.eventId,track=t,index=1,start=GetGameTimer()}
    end)
end)
CreateThread(function()
    while true do
        local sleep=1000
        local r=LRRPV9.advancedRace
        if r then
            sleep=0; local p=GetEntityCoords(PlayerPedId()); local cp=r.track.checkpoints[r.index]
            if cp then
                Citizen.InvokeNative(0x2A32FAA57B937173,0x6903B113,cp.x,cp.y,cp.z-0.8,0,0,0,0,0,0,1.6,1.6,1.6,255,220,120,190,false,false,2,false,nil,nil,false)
                if #(p-cp)<5.5 then TriggerServerEvent('lrrp_stables:raceCheckpointV9',r.eventId,r.index); r.index=r.index+1; TriggerEvent('lrrp_stables:notify',('Checkpoint %d/%d'):format(r.index-1,#r.track.checkpoints)) end
            else
                local f=r.track.finish; Citizen.InvokeNative(0x2A32FAA57B937173,0x6903B113,f.x,f.y,f.z-0.8,0,0,0,0,0,0,1.8,1.8,1.8,120,255,120,210,false,false,2,false,nil,nil,false)
                if #(p-f)<5.5 then local ms=GetGameTimer()-r.start; TriggerServerEvent('lrrp_stables:finishMultiplayerRace',r.eventId,ms); TriggerEvent('lrrp_stables:notify',('Tempo: %.2fs'):format(ms/1000)); LRRPV9.advancedRace=nil end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('lrrp_stables:startFarrierMinigameClient',function(data)
    local seq={'ESQ','DIR','ESQ','DIR'}; CreateThread(function()
        for i,label in ipairs(seq) do local hash=(label=='ESQ' and 0x7065027D or 0xB4E465B4); local ok=false; local untilAt=GetGameTimer()+1800
            while GetGameTimer()<untilAt do Wait(0); TriggerEvent('vorp:TipBottom',('Ferrador %d/4 — %s'):format(i,label),200); if IsControlJustReleased(0,hash) then ok=true break end end
            if not ok then return TriggerEvent('lrrp_stables:notify','Falha no trabalho de ferrador.') end
        end
        TriggerServerEvent('lrrp_stables:professionalFarrierComplete',data.horseId,data.level)
    end)
end)

RegisterNUICallback('buildRanchStructure',function(data,cb)
    local p=GetEntityCoords(PlayerPedId()); local h=GetEntityHeading(PlayerPedId())
    TriggerServerEvent('lrrp_stables:buildRanchStructure',tostring(data.kind),{x=p.x,y=p.y,z=p.z,heading=h})
    cb({ok=true})
end)
RegisterNUICallback('stockPhysicalRanch',function(data,cb) TriggerServerEvent('lrrp_stables:stockPhysicalRanch',tostring(data.kind),tonumber(data.amount)); cb({ok=true}) end)
RegisterNUICallback('loadHorseTransport',function(data,cb) TriggerServerEvent('lrrp_stables:loadHorseTransport',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('unloadHorseTransport',function(_,cb) TriggerServerEvent('lrrp_stables:unloadHorseTransport'); cb({ok=true}) end)
RegisterNUICallback('vetTreatV9',function(data,cb) TriggerServerEvent('lrrp_stables:professionalVetTreat',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('farrierMinigameV9',function(data,cb) StableUI.closeMenu(); TriggerEvent('lrrp_stables:startFarrierMinigameClient',{horseId=tonumber(data.id),level=tonumber(data.level)}); cb({ok=true}) end)
RegisterNUICallback('staffEconomyAction',function(data,cb) TriggerServerEvent('lrrp_stables:staffEconomyAction',tostring(data.action),data.value); cb({ok=true}) end)


RegisterNUICallback('spectateRaceV9',function(data,cb)
    local key=tostring(data.key or ''); local t=nil
    for _,x in ipairs(Config.AdvancedRacing.tracks or {}) do if x.key==key then t=x break end end
    if t then
        StableUI.closeMenu()
        if LRRPV9.spectatorCam then DestroyCam(LRRPV9.spectatorCam,false) end
        local f=t.finish; local cam=CreateCam('DEFAULT_SCRIPTED_CAMERA',true)
        SetCamCoord(cam,f.x+8.0,f.y+8.0,f.z+5.0); PointCamAtCoord(cam,f.x,f.y,f.z+1.0); SetCamActive(cam,true); RenderScriptCams(true,true,700,true,true)
        LRRPV9.spectatorCam=cam; LRRPV9.spectating=true
        TriggerEvent('lrrp_stables:notify','Modo espectador ativo. Pressione BACKSPACE para sair.')
    end
    cb({ok=true})
end)
CreateThread(function()
    while true do
        if LRRPV9.spectating then
            Wait(0)
            if IsControlJustReleased(0,0x156F7119) then
                RenderScriptCams(false,true,500,true,true); if LRRPV9.spectatorCam then DestroyCam(LRRPV9.spectatorCam,false) end
                LRRPV9.spectatorCam=nil; LRRPV9.spectating=false
            end
        else Wait(500) end
    end
end)

AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    deleteEntitySafe(LRRPV9.wagon); deleteEntitySafe(LRRPV9.wildHorse); clearStructures(); if LRRPV9.spectatorCam then RenderScriptCams(false,false,0,true,true); DestroyCam(LRRPV9.spectatorCam,false) end
end)
