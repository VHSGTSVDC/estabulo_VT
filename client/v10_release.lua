-- LRRP_Stables v1.0.0 - client release layer
LRRPV10Client={data={},placement=nil,wear={horse=0,last=nil,distance=0}}

local function notify(msg) TriggerEvent('lrrp_stables:notify',msg) end
local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash); local untilAt=GetGameTimer()+5000
    while not HasModelLoaded(hash) and GetGameTimer()<untilAt do Wait(0) end
    return HasModelLoaded(hash)
end
local function del(e) if e and e~=0 and DoesEntityExist(e) then SetEntityAsMissionEntity(e,true,true); DeleteEntity(e) end end

RegisterNetEvent('lrrp_stables:v10DataClient',function(data)
    LRRPV10Client.data=data or {}
    if StableUI and StableUI.open then SendNUIMessage({action='v10Data',data=LRRPV10Client.data}) end
end)
RegisterNetEvent('lrrp_stables:refreshV10',function() TriggerServerEvent('lrrp_stables:v10Data') end)
CreateThread(function() Wait(9000); TriggerServerEvent('lrrp_stables:v10Data') end)

local function finishPlacement(confirm)
    local p=LRRPV10Client.placement; if not p then return end
    if confirm then
        local c=GetEntityCoords(p.obj); TriggerServerEvent('lrrp_stables:confirmStructurePlacementV10',p.kind,{x=c.x,y=c.y,z=c.z,heading=GetEntityHeading(p.obj)})
    end
    del(p.obj); LRRPV10Client.placement=nil
    if StableUI and not StableUI.open then StableUI.openMenu() end
end

RegisterNetEvent('lrrp_stables:startStructureEditorV10',function(kind)
    if LRRPV10Client.placement then finishPlacement(false) end
    local def=Config.RanchBuilding.structures[tostring(kind or '')]; if not def then return end
    local hash=joaat(def.prop); if not loadModel(hash) then return notify('Modelo da estrutura indisponível nesta build.') end
    local ped=PlayerPedId(); local c=GetEntityCoords(ped); local h=GetEntityHeading(ped); local rad=math.rad(h); local x=c.x-math.sin(rad)*3.0; local y=c.y+math.cos(rad)*3.0
    local obj=CreateObject(hash,x,y,c.z,false,false,false); SetEntityAsMissionEntity(obj,true,true); SetEntityAlpha(obj,180,false); FreezeEntityPosition(obj,true); SetEntityCollision(obj,false,false); SetEntityHeading(obj,h)
    SetModelAsNoLongerNeeded(hash); LRRPV10Client.placement={obj=obj,kind=kind}
    CreateThread(function()
        while LRRPV10Client.placement do
            Wait(0); local p=LRRPV10Client.placement; local o=p.obj; local pos=GetEntityCoords(o); local heading=GetEntityHeading(o); local step=IsControlPressed(0,0x8FFC75D6) and 0.12 or 0.04
            if IsControlPressed(0,0x8FD015D8) then local r=math.rad(heading); SetEntityCoordsNoOffset(o,pos.x-math.sin(r)*step,pos.y+math.cos(r)*step,pos.z,false,false,false) end
            if IsControlPressed(0,0xD27782E3) then local r=math.rad(heading); SetEntityCoordsNoOffset(o,pos.x+math.sin(r)*step,pos.y-math.cos(r)*step,pos.z,false,false,false) end
            if IsControlPressed(0,0x7065027D) then SetEntityHeading(o,heading-0.7) end
            if IsControlPressed(0,0xB4E465B4) then SetEntityHeading(o,heading+0.7) end
            TriggerEvent('vorp:TipBottom','W/S mover • A/D girar • ENTER confirmar • BACKSPACE cancelar',100)
            if IsControlJustReleased(0,0xC7B5340A) then finishPlacement(true) break end
            if IsControlJustReleased(0,0x156F7119) then finishPlacement(false) break end
        end
    end)
end)

RegisterNetEvent('lrrp_stables:startDisciplineTrainingV10',function(data)
    if not data or not data.horseId or not data.discipline then return end
    if GetMount(PlayerPedId())==0 then return notify('Monte no cavalo antes do treinamento.') end
    local sequence={{'W',0x8FD015D8},{'A',0x7065027D},{'D',0xB4E465B4},{'S',0xD27782E3}}; local score=0; local rounds=math.max(4,tonumber(data.rounds) or 6)
    CreateThread(function()
        for i=1,rounds do local item=sequence[math.random(1,#sequence)]; local limit=GetGameTimer()+1800; local ok=false
            while GetGameTimer()<limit do Wait(0); TriggerEvent('vorp:TipBottom',('Treino %d/%d • pressione %s'):format(i,rounds,item[1]),120); if IsControlJustReleased(0,item[2]) then ok=true break end end
            if ok then score=score+math.floor(100/rounds) end
        end
        TriggerServerEvent('lrrp_stables:completeDisciplineTrainingV10',data.horseId,data.discipline,math.min(100,score),data.token)
    end)
end)

RegisterNetEvent('lrrp_stables:startVetDiagnosisV10',function(data)
    local checks={{'Observar respiração',0xC7B5340A},{'Verificar locomoção',0x7065027D},{'Examinar patas',0xB4E465B4},{'Conferir pulso',0x8FD015D8}}; local score=0
    CreateThread(function()
        for i,c in ipairs(checks) do local untilAt=GetGameTimer()+2200; local ok=false
            while GetGameTimer()<untilAt do Wait(0); TriggerEvent('vorp:TipBottom',('%s • siga a indicação [%d/4]'):format(c[1],i),120); if IsControlJustReleased(0,c[2]) then ok=true break end end
            if ok then score=score+25 end
        end
        TriggerServerEvent('lrrp_stables:vetDiagnosisCompleteV10',data.horseId,score,data.token)
    end)
end)

local activeWildNameToken=nil

RegisterNetEvent('lrrp_stables:requestWildHorseNameV10',function(data)
    if not data or not data.token then return end
    if activeWildNameToken==tostring(data.token) then
        print('[estabulo_VT] NUI DOMA | evento duplicado ignorado')
        return
    end
    activeWildNameToken=tostring(data.token)

    -- Fecha qualquer menu anterior e força foco exclusivo na tela de nome.
    if StableUI and StableUI.open then
        StableUI.closeMenu()
        Wait(100)
    end

    SetNuiFocus(false,false)
    SetNuiFocusKeepInput(false)
    Wait(50)

    SendNUIMessage({action='wildName',data=data})
    Wait(50)

    SetNuiFocus(true,true)
    SetNuiFocusKeepInput(false)

    print('[estabulo_VT] NUI DOMA | foco/cursor ativados')
end)

-- desgaste por distância do cavalo montado; o servidor limita frequência/metros por tick
CreateThread(function()
    while true do
        Wait(5000)
        local mount=GetMount(PlayerPedId())
        if mount and mount~=0 then
            local pos=GetEntityCoords(PlayerPedId()); local w=LRRPV10Client.wear
            if w.last then local d=#(pos-w.last); if d<250 then w.distance=w.distance+d end end; w.last=pos
            local active=HorseState and HorseState.data and HorseState.data.id or nil
            if active and w.distance>=100 then TriggerServerEvent('lrrp_stables:horseShoeWearV10',active,math.floor(w.distance)); w.distance=0 end
        else LRRPV10Client.wear.last=nil end
    end
end)

RegisterNUICallback('ranchInviteV10',function(data,cb) TriggerServerEvent('lrrp_stables:ranchInvite',tonumber(data.target),tostring(data.role)); cb({ok=true}) end)
RegisterNUICallback('ranchRemoveMemberV10',function(data,cb) TriggerServerEvent('lrrp_stables:ranchRemoveMember',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('editStructureV10',function(data,cb) StableUI.closeMenu(); TriggerEvent('lrrp_stables:startStructureEditorV10',tostring(data.kind)); cb({ok=true}) end)
RegisterNUICallback('repairStructureV10',function(data,cb) TriggerServerEvent('lrrp_stables:repairStructureV10',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('disciplineTrainV10',function(data,cb) StableUI.closeMenu(); TriggerServerEvent('lrrp_stables:requestDisciplineTrainingV10',tonumber(data.id),tostring(data.discipline)); cb({ok=true}) end)
RegisterNUICallback('vetDiagnosisV10',function(data,cb) StableUI.closeMenu(); TriggerServerEvent('lrrp_stables:requestVetDiagnosisV10',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('wildNameConfirmV10',function(data,cb)
    activeWildNameToken=nil
    SetNuiFocus(false,false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action='wildNameClose'})
    TriggerServerEvent('lrrp_stables:saveWildNameV10',tostring(data.token or ''),tostring(data.name or 'Cavalo Selvagem'))
    cb({ok=true})
end)

RegisterNUICallback('wildNameCancelV10',function(_,cb)
    activeWildNameToken=nil
    SetNuiFocus(false,false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action='wildNameClose'})
    TriggerEvent('lrrp_stables:notify','Nomeação cancelada. A doma não foi salva.')
    cb({ok=true})
end)
RegisterNUICallback('adminV10Action',function(data,cb) TriggerServerEvent('lrrp_stables:adminV10Action',tostring(data.action),tonumber(data.id),tonumber(data.value)); cb({ok=true}) end)

AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() and LRRPV10Client.placement then del(LRRPV10Client.placement.obj) end end)
