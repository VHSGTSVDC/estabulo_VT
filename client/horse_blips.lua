-- estabulo_VT v3.0.5 - blip do cavalo ativo
HorseBlipV305 = HorseBlipV305 or {
    blip=0,
    entity=0,
    horseId=nil
}

local BLIP_ADD_FOR_ENTITY = 0x23F74C2FDA6E7C61
local SET_BLIP_NAME       = 0x9CB1A1623062F402

local function removeHorseBlip()
    if HorseBlipV305.blip and HorseBlipV305.blip~=0 then
        if DoesBlipExist(HorseBlipV305.blip) then
            RemoveBlip(HorseBlipV305.blip)
        end
    end
    HorseBlipV305.blip=0
    HorseBlipV305.entity=0
    HorseBlipV305.horseId=nil
end

local function addHorseBlip(entity,data)
    if not Config.HorseBlips or not Config.HorseBlips.enabled then return end
    if not Config.HorseBlips.activeHorse or not Config.HorseBlips.activeHorse.enabled then return end
    if not entity or entity==0 or not DoesEntityExist(entity) then return end

    removeHorseBlip()

    local hash=tonumber(Config.HorseBlips.activeHorse.blipHash) or -1230993421
    local blip=Citizen.InvokeNative(BLIP_ADD_FOR_ENTITY,hash,entity)

    if blip and blip~=0 then
        local horseName=(data and data.name) or Config.HorseBlips.activeHorse.name or 'Meu Cavalo'
        pcall(function()
            Citizen.InvokeNative(SET_BLIP_NAME,blip,tostring(horseName))
        end)

        HorseBlipV305.blip=blip
        HorseBlipV305.entity=entity
        HorseBlipV305.horseId=data and tonumber(data.id) or nil

        print(('[estabulo_VT v3.0.5] BLIP CAVALO OK | entity=%s id=%s nome=%s'):format(
            tostring(entity),
            tostring(HorseBlipV305.horseId),
            tostring(horseName)
        ))
    else
        print('[estabulo_VT v3.0.5] BLIP CAVALO ERRO | não foi possível criar o blip.')
    end
end

RegisterNetEvent('lrrp_stables:updateActiveHorseBlipV305',function(entity,data)
    addHorseBlip(tonumber(entity) or 0,data)
end)

RegisterNetEvent('lrrp_stables:removeActiveHorseBlipV305',function()
    removeHorseBlip()
end)

-- Watchdog: também cobre respawn visual da v3.0.1.
CreateThread(function()
    while true do
        Wait(1000)

        if HorseState and HorseState.entity and HorseState.entity~=0
           and DoesEntityExist(HorseState.entity) and HorseState.data then

            if HorseBlipV305.entity~=HorseState.entity
               or not HorseBlipV305.blip
               or HorseBlipV305.blip==0
               or not DoesBlipExist(HorseBlipV305.blip) then
                addHorseBlip(HorseState.entity,HorseState.data)
            end
        else
            if HorseBlipV305.blip and HorseBlipV305.blip~=0 then
                removeHorseBlip()
            end
        end
    end
end)

AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    removeHorseBlip()
end)
