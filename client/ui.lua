StableUI = { open=false, selected=nil, stableIndex=1 }
local function send(action,data) SendNUIMessage({action=action,data=data}) end

local function nearestStable()
    local pc=GetEntityCoords(PlayerPedId()); local best,bestD=1,999999.0
    for i,stable in ipairs(Config.Stables) do local d=#(pc-stable.coords); if d<bestD then best,bestD=i,d end end
    return best
end
local function showroomOwned(id)
    local h=byId(id); if not h then return nil end
    Showroom.show(h); StableUI.selected=h.id; return h
end
function StableUI.openMenu(stableIndex)
    if StableUI.open then return end
    StableUI.open=true; StableUI.stableIndex=tonumber(stableIndex) or nearestStable(); StableCinematic.enter(); Showroom.open(StableUI.stableIndex)
    SetNuiFocus(true,true)
    TriggerServerEvent('lrrp_stables:v10Data')
    send('open',{horses=Horses or {},shop=LRRPHorseCatalog or {},currency=Config.Currency,accessories=LRRPAccessoryCatalog,accessoryCategories=LRRPAccessoryCategories,ownedAccessories={},horseshoes=(Config.Horseshoes and Config.Horseshoes.levels) or {},stableName=(Config.Stables[StableUI.stableIndex] or {}).name})
    TriggerServerEvent('lrrp_stables:requestUIData'); TriggerServerEvent('lrrp_stables:v6Data'); TriggerServerEvent('lrrp_stables:v7Data'); TriggerServerEvent('lrrp_stables:v8Data'); TriggerServerEvent('lrrp_stables:v9Data'); Wait(80); StableCinematic.reveal()
end
function StableUI.closeMenu()
    TriggerEvent('lrrp_stables:cancelAccessoryPreview'); Showroom.close(); StableUI.open=false; SetNuiFocus(false,false); send('close',{}); StableCinematic.exit()
end

AddEventHandler('lrrp_stables:uiDataLocal',function(data) if StableUI.open then send('uiData',data or {}) end end)
RegisterNUICallback('close',function(_,cb) StableUI.closeMenu(); cb({ok=true}) end)
RegisterNUICallback('refresh',function(_,cb) TriggerServerEvent('lrrp_stables:requestUIData'); cb({ok=true}) end)
RegisterNUICallback('previewOwned',function(data,cb) local h=showroomOwned(data.id); cb({ok=h~=nil}) end)
RegisterNUICallback('previewShop',function(data,cb) local item=LRRPHorseFind(tostring(data.model or '')); local ok=item and Showroom.show(item) or false; cb({ok=ok}) end)
RegisterNUICallback('rotateHorse',function(data,cb) Showroom.rotateHorse(tonumber(data.delta) or 0); cb({ok=true}) end)
RegisterNUICallback('orbitCamera',function(data,cb) Showroom.orbit(tonumber(data.delta) or 0); cb({ok=true}) end)
RegisterNUICallback('zoomCamera',function(data,cb) Showroom.zoom(tonumber(data.delta) or 0); cb({ok=true}) end)
RegisterNUICallback('spawn',function(data,cb) local h=byId(data.id); if h then StableUI.closeMenu(); HorseState.spawn(h) end; cb({ok=h~=nil}) end)
RegisterNUICallback('dismiss',function(data,cb)
    local h=data and byId(data.id)
    if HorseState.data and (not h or tonumber(HorseState.data.id)==tonumber(h.id)) then
        StableUI.closeMenu()
        HorseState.dismiss('away')
        cb({ok=true})
    else
        TriggerEvent('lrrp_stables:notify','Este cavalo já está guardado.')
        cb({ok=false})
    end
end)

RegisterNUICallback('storeHorse',function(data,cb)
    local h=data and byId(data.id)
    if HorseState.data and h and tonumber(HorseState.data.id)==tonumber(h.id) then
        StableUI.closeMenu()
        HorseState.dismiss('stable')
        cb({ok=true})
    else
        TriggerEvent('lrrp_stables:notify','Este cavalo já está guardado.')
        cb({ok=false})
    end
end)
RegisterNUICallback('primary',function(data,cb) TriggerServerEvent('lrrp_stables:setPrimary',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('bag',function(data,cb) StableUI.closeMenu(); TriggerServerEvent('lrrp_stables:openBag',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('action',function(data,cb) StableUI.closeMenu(); local h=byId(data.id); if h then HorseState.spawn(h); Wait(250); HorseState.action(tostring(data.action)) end; cb({ok=h~=nil}) end)
RegisterNUICallback('sell',function(data,cb) TriggerServerEvent('lrrp_stables:sell',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('transfer',function(data,cb) TriggerServerEvent('lrrp_stables:transfer',tonumber(data.id),tonumber(data.target)); cb({ok=true}) end)
RegisterNUICallback('buy',function(data,cb) TriggerServerEvent('lrrp_stables:buy',tostring(data.model),tostring(data.name or 'Cavalo'),tostring(data.sex or 'male')); cb({ok=true}) end)
RegisterNUICallback('buyHorseshoe',function(data,cb) TriggerServerEvent('lrrp_stables:buyHorseshoe',tonumber(data.id),tonumber(data.level)); cb({ok=true}) end)
RegisterNUICallback('buyAccessory',function(data,cb) TriggerServerEvent('lrrp_stables:buyAccessory',tostring(data.key),tostring(data.component)); cb({ok=true}) end)
RegisterNUICallback('previewAccessory',function(data,cb)
    local h=showroomOwned(data.id); if h then TriggerEvent('lrrp_stables:previewAccessory',tostring(data.key),tostring(data.component or '0')) end; cb({ok=h~=nil})
end)
RegisterNUICallback('cancelAccessoryPreview',function(_,cb) TriggerEvent('lrrp_stables:cancelAccessoryPreview'); cb({ok=true}) end)
RegisterNUICallback('equipAccessory',function(data,cb)
    local h=showroomOwned(data.id); if h then TriggerServerEvent('lrrp_stables:setAccessory',h.id,tostring(data.key),tostring(data.component or '0')) end; cb({ok=h~=nil})
end)
RegisterNUICallback('removeAccessory',function(data,cb)
    local h=showroomOwned(data.id); if h then TriggerServerEvent('lrrp_stables:setAccessory',h.id,tostring(data.key),'0') end; cb({ok=h~=nil})
end)

CreateThread(function()
    while true do
        local sleep=1000; local pc=GetEntityCoords(PlayerPedId())
        for i,stable in ipairs(Config.Stables) do
            local d=#(pc-stable.coords)
            if d<15.0 then sleep=0; if d<=(stable.radius or Config.UI.interactionDistance) then
                TriggerEvent('vorp:TipBottom',('Pressione [E] para abrir o Estábulo - %s'):format(stable.name),1000)
                if IsControlJustReleased(0,Config.UI.openControl) and not StableUI.open then print(('[estabulo_VT v1.1.9] TECLA G | estabulo=%s'):format(tostring(stable.name))); StableUI.openMenu(i) end
            end end
        end
        Wait(sleep)
    end
end)
RegisterCommand(Config.UI.command,function() StableUI.openMenu(nearestStable()) end,false)
AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then if StableUI.open then SetNuiFocus(false,false) end; Showroom.close() end end)

RegisterNUICallback('breed',function(data,cb) TriggerServerEvent('lrrp_stables:breed',tonumber(data.motherId),tonumber(data.fatherId),tostring(data.name or 'Potro')); cb({ok=true}) end)
RegisterNUICallback('treatHorse',function(data,cb) TriggerServerEvent('lrrp_stables:treatHorse',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('setSex',function(data,cb) TriggerServerEvent('lrrp_stables:setSex',tonumber(data.id),tostring(data.sex)); cb({ok=true}) end)
RegisterNUICallback('startRace',function(data,cb) StableUI.closeMenu(); TriggerServerEvent('lrrp_stables:startRace',tostring(data.key),tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('listMarket',function(data,cb) TriggerServerEvent('lrrp_stables:listMarket',tonumber(data.id),tonumber(data.price),tonumber(data.currency)); cb({ok=true}) end)
RegisterNUICallback('buyMarket',function(data,cb) TriggerServerEvent('lrrp_stables:buyMarket',tonumber(data.listingId)); cb({ok=true}) end)
RegisterNUICallback('cancelMarket',function(data,cb) TriggerServerEvent('lrrp_stables:cancelMarket',tonumber(data.id)); cb({ok=true}) end)


-- v0.7 NUI callbacks
RegisterNUICallback('createRanch',function(data,cb)
    local c=GetEntityCoords(PlayerPedId()); TriggerServerEvent('lrrp_stables:createRanch',tostring(data.name or 'Meu Rancho'),{x=c.x,y=c.y,z=c.z}); cb({ok=true})
end)
RegisterNUICallback('upgradeRanch',function(_,cb) TriggerServerEvent('lrrp_stables:upgradeRanch'); cb({ok=true}) end)
RegisterNUICallback('assignRanch',function(data,cb) TriggerServerEvent('lrrp_stables:assignRanch',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('startPregnancy',function(data,cb) TriggerServerEvent('lrrp_stables:startPregnancy',tonumber(data.motherId),tonumber(data.fatherId),tostring(data.name or 'Potro')); cb({ok=true}) end)
RegisterNUICallback('pedigreeCertificate',function(data,cb) TriggerServerEvent('lrrp_stables:pedigreeCertificate',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('insureHorse',function(data,cb) TriggerServerEvent('lrrp_stables:insureHorse',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('claimInsurance',function(data,cb) TriggerServerEvent('lrrp_stables:claimInsurance',tonumber(data.id)); cb({ok=true}) end)
RegisterNUICallback('createAuction',function(data,cb) TriggerServerEvent('lrrp_stables:createAuction',tonumber(data.id),tonumber(data.price),tonumber(data.currency),tonumber(data.duration)); cb({ok=true}) end)
RegisterNUICallback('bidAuction',function(data,cb) TriggerServerEvent('lrrp_stables:bidAuction',tonumber(data.auctionId),tonumber(data.bid)); cb({ok=true}) end)

RegisterNUICallback('horseCare',function(data,cb)
    local action=tostring((data and data.action) or '')
    TriggerEvent('lrrp_stables:closeHorseCareContext')
    if action=='dismiss' then
        if HorseState.data and HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
            HorseState.dismiss('away')
        else
            TriggerEvent('lrrp_stables:notify','Nenhum cavalo ativo.')
        end
    elseif action=='follow' or action=='stay' or action=='graze' then
        HorseState.setBehavior(action)
    elseif action=='temperament' then
        if HorseState.data then
            TriggerServerEvent('lrrp_stables:getTemperament',HorseState.data.id)
        else
            TriggerEvent('lrrp_stables:notify','Chame seu cavalo primeiro.')
        end
    elseif action=='health' then
        if HorseState.data then
            TriggerServerEvent('lrrp_stables:healthStatusV23',HorseState.data.id)
        else
            TriggerEvent('lrrp_stables:notify','Chame seu cavalo primeiro.')
        end
    elseif action=='fixvisual' then
        CreateThread(function()
            HorseState.repairVisual(false)
        end)
    elseif action=='bag' then
        if HorseState.data and HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
            TriggerServerEvent('lrrp_stables:openBag',HorseState.data.id)
        else
            TriggerEvent('lrrp_stables:notify','Chame seu cavalo primeiro.')
        end
    elseif action=='train' then
        HorseState.action('train')
    elseif action=='river' then
        if HorseState.isNearWater() then HorseState.action('river')
        else TriggerEvent('lrrp_stables:notify','Entre na água do rio com o cavalo ao seu lado.') end
    elseif action=='pet' or action=='brush' or action=='feed' or action=='water' then
        HorseState.action(action)
    end
    cb({ok=true})
end)

RegisterNUICallback('closeHorseContext',function(_,cb)
    TriggerEvent('lrrp_stables:closeHorseCareContext')
    cb({ok=true})
end)

RegisterNUICallback('transferReply',function(data,cb)
    SetNuiFocus(false,false)
    TriggerServerEvent('lrrp_stables:transferReply',tostring(data.token or ''),data.accepted==true)
    cb({ok=true})
end)

RegisterNUICallback('removeFromRanch',function(data,cb)
    TriggerServerEvent('lrrp_stables:removeFromRanch',tonumber(data.id))
    cb({ok=true})
end)

RegisterNUICallback('stockRanchWater',function(data,cb)
    TriggerServerEvent('lrrp_stables:stockRanchWater',tonumber(data.amount) or 1)
    cb({ok=true})
end)

RegisterNUICallback('trainerServiceRequest',function(data,cb)
    TriggerServerEvent('lrrp_stables:trainerServiceRequest',
        tonumber(data.id),
        tostring(data.discipline or ''),
        tonumber(data.target)
    )
    cb({ok=true})
end)

RegisterNUICallback('startSoloTraining',function(data,cb)
    local horseId=tonumber(data.id)
    local discipline=tostring(data.discipline or '')
    StableUI.closeMenu()
    Wait(150)
    TriggerServerEvent('lrrp_stables:startSoloTraining',horseId,discipline)
    cb({ok=true})
end)
