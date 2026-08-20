-- estabulo_VT v3.0.3 - NPC de suprimentos
SupplyShop = SupplyShop or { npcs={} }

local BLIP_ADD_FOR_ENTITY = 0x23F74C2FDA6E7C61
local SET_BLIP_NAME       = 0x9CB1A1623062F402

local function addSupplyNpcBlip(ped,shop)
    if not Config.HorseBlips or not Config.HorseBlips.enabled then return 0 end
    if not Config.HorseBlips.supplyNpc or not Config.HorseBlips.supplyNpc.enabled then return 0 end
    if not ped or ped==0 or not DoesEntityExist(ped) then return 0 end

    local hash=tonumber(Config.HorseBlips.supplyNpc.blipHash) or -1230993421
    local blip=Citizen.InvokeNative(BLIP_ADD_FOR_ENTITY,hash,ped)

    if blip and blip~=0 then
        local name=(shop and shop.label) or Config.HorseBlips.supplyNpc.name or 'Suprimentos para Cavalos'
        pcall(function()
            Citizen.InvokeNative(SET_BLIP_NAME,blip,tostring(name))
        end)
        print(('[estabulo_VT v3.0.5] BLIP NPC SUPRIMENTOS OK | loja=%s entity=%s'):format(
            tostring(name),tostring(ped)
        ))
        return blip
    end

    print(('[estabulo_VT v3.0.5] BLIP NPC SUPRIMENTOS ERRO | loja=%s'):format(
        tostring(shop and shop.label or '?')
    ))
    return 0
end

local function loadModel(hash)
    RequestModel(hash)
    local untilAt=GetGameTimer()+10000
    while not HasModelLoaded(hash) and GetGameTimer()<untilAt do Wait(50) end
    return HasModelLoaded(hash)
end

local function spawnNpc(data)
    local hash=joaat(Config.SupplyShop.npcModel)
    if not loadModel(hash) then
        print(('[estabulo_VT v3.0.4] NPC SUPRIMENTOS ERRO MODELO | %s'):format(tostring(Config.SupplyShop.npcModel)))
        return nil
    end

    -- As coordenadas copiadas do jogador representam os pés/centro do player.
    -- Para PEDs do RedM, -1.0 no Z evita spawn acima/abaixo do chão em vários interiores/terrenos.
    local spawnZ=(tonumber(data.coords.z) or 0.0)-1.0
    local x,y,heading=data.coords.x,data.coords.y,data.coords.w or 0.0

    local ped=CreatePed(hash,x,y,spawnZ,heading,false,false,false,false)
    if (not ped) or ped==0 or not DoesEntityExist(ped) then
        ped=Citizen.InvokeNative(
            0xD49F9B0955C367DE,
            hash,x,y,spawnZ,heading,
            false,false,false,false
        )
    end

    if ped and ped~=0 and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped,true,true)
        SetEntityHeading(ped,heading)
        SetEntityInvincible(ped,true)
        SetBlockingOfNonTemporaryEvents(ped,true)

        -- Fundamental em vários modelos humanos do RedM:
        -- força outfit/variação do PED para ele não existir "sem corpo".
        pcall(function()
            Citizen.InvokeNative(0x283978A15512B2FE,ped,true)
        end)

        pcall(function()
            PlaceEntityOnGroundProperly(ped,true)
        end)

        Wait(100)

        SetEntityVisible(ped,true,false)
        ResetEntityAlpha(ped)
        SetEntityAlpha(ped,255,false)
        FreezeEntityPosition(ped,true)
        TaskStandStill(ped,-1)

        -- Segunda atualização visual depois do streaming.
        Wait(250)
        pcall(function()
            Citizen.InvokeNative(0x283978A15512B2FE,ped,true)
        end)
        SetEntityVisible(ped,true,false)
        ResetEntityAlpha(ped)

        local npcBlip=addSupplyNpcBlip(ped,data)
        SupplyShop.npcs[#SupplyShop.npcs+1]={ped=ped,data=data,blip=npcBlip}

        local pc=GetEntityCoords(ped)
        print(('[estabulo_VT v3.0.4] NPC SUPRIMENTOS OK | loja=%s entity=%s visible=%s alpha=%s coords=%.2f %.2f %.2f'):format(
            tostring(data.label),tostring(ped),tostring(IsEntityVisible(ped)),
            tostring(GetEntityAlpha(ped)),pc.x,pc.y,pc.z
        ))

        return ped
    end

    print(('[estabulo_VT v3.0.4] NPC SUPRIMENTOS ERRO SPAWN | loja=%s coords=%.2f %.2f %.2f'):format(
        tostring(data.label),x,y,spawnZ
    ))
    return nil
end

CreateThread(function()
    if not Config.SupplyShop.enabled then return end
    Wait(1000)

    for _,shop in ipairs(Config.SupplyShop.shops or {}) do
        spawnNpc(shop)
    end

    while true do
        local sleep=900
        local player=PlayerPedId()
        local pcoords=GetEntityCoords(player)

        for _,entry in ipairs(SupplyShop.npcs) do
            if entry.ped and DoesEntityExist(entry.ped) then
                local ncoords=GetEntityCoords(entry.ped)
                local dist=#(pcoords-ncoords)

                if dist<12.0 then
                    sleep=0
                    if dist<=(Config.SupplyShop.interactionDistance or 2.5) and not StableUI.open then
                        TriggerEvent('vorp:TipBottom','[G] Comprar suprimentos para cavalos',120)
                        local ctrl=Config.SupplyShop.interactionControl or 0x760A9C6F
                        if IsControlJustReleased(0,ctrl) or IsDisabledControlJustReleased(0,ctrl) then
                            SetNuiFocus(true,true)
                            SendNUIMessage({
                                action='openSupplyShop',
                                data={
                                    label=entry.data.label,
                                    items=Config.SupplyShop.items
                                }
                            })
                            Wait(500)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterNUICallback('closeSupplyShop',function(_,cb)
    SetNuiFocus(false,false)
    cb({ok=true})
end)

RegisterNUICallback('buySupplyItem',function(data,cb)
    TriggerServerEvent('lrrp_stables:buySupplyItem',tostring(data.item or ''),tonumber(data.amount) or 1)
    cb({ok=true})
end)


-- v3.0.4: repara NPC caso o streaming/local PED desapareça.
CreateThread(function()
    while true do
        Wait(5000)
        if Config.SupplyShop.enabled then
            for _,shop in ipairs(Config.SupplyShop.shops or {}) do
                local found=false
                for _,entry in ipairs(SupplyShop.npcs) do
                    if entry.data==shop and entry.ped and DoesEntityExist(entry.ped) then
                        found=true

                        if Config.HorseBlips and Config.HorseBlips.enabled
                           and Config.HorseBlips.supplyNpc and Config.HorseBlips.supplyNpc.enabled
                           and (not entry.blip or entry.blip==0 or not DoesBlipExist(entry.blip)) then
                            entry.blip=addSupplyNpcBlip(entry.ped,entry.data)
                        end

                        if not IsEntityVisible(entry.ped) or GetEntityAlpha(entry.ped)<=10 then
                            SetEntityVisible(entry.ped,true,false)
                            ResetEntityAlpha(entry.ped)
                            pcall(function() Citizen.InvokeNative(0x283978A15512B2FE,entry.ped,true) end)
                        end
                        break
                    end
                end
                if not found then
                    spawnNpc(shop)
                end
            end
        end
    end
end)

RegisterCommand('npcsuprimentos',function()
    local player=PlayerPedId()
    local p=GetEntityCoords(player)
    local nearest=nil
    local best=99999.0

    for _,shop in ipairs(Config.SupplyShop.shops or {}) do
        local dx=p.x-shop.coords.x
        local dy=p.y-shop.coords.y
        local dz=p.z-shop.coords.z
        local d=math.sqrt(dx*dx+dy*dy+dz*dz)
        if d<best then best=d nearest=shop end
    end

    if nearest then
        TriggerEvent('lrrp_stables:notify',('NPC mais próximo: %s • %.1fm'):format(nearest.label,best))
        print(('[estabulo_VT v3.0.4] DEBUG NPC | mais proximo=%s distancia=%.2f'):format(nearest.label,best))
    end
end,false)

AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    for _,entry in ipairs(SupplyShop.npcs) do
        if entry.blip and entry.blip~=0 and DoesBlipExist(entry.blip) then
            RemoveBlip(entry.blip)
        end
        if entry.ped and DoesEntityExist(entry.ped) then
            DeleteEntity(entry.ped)
        end
    end
end)
