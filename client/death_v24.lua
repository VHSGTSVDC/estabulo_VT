-- estabulo_VT v2.4.0 - estado crítico do cavalo
local criticalHorseId=nil
local lastZeroReport=0

RegisterNetEvent('lrrp_stables:requestCriticalConfirmV24',function(horseId)
    if not HorseState.data or tonumber(HorseState.data.id)~=tonumber(horseId) then return end
    if HorseState.entity==0 or not DoesEntityExist(HorseState.entity) then return end
    if IsEntityDead(HorseState.entity) or GetEntityHealth(HorseState.entity)<=1 then
        TriggerServerEvent('lrrp_stables:criticalHorseV24',horseId)
    end
end)

RegisterNetEvent('lrrp_stables:horseCriticalClientV24',function(horseId)
    if not HorseState.data or tonumber(HorseState.data.id)~=tonumber(horseId) then return end
    criticalHorseId=tonumber(horseId)
    if HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
        pcall(function()
            ResurrectPed(HorseState.entity)
            SetEntityHealth(HorseState.entity,1)
            FreezeEntityPosition(HorseState.entity,true)
            TaskStandStill(HorseState.entity,-1)
        end)
    end
end)

RegisterNetEvent('lrrp_stables:horseRevivedClientV24',function(horseId)
    if tonumber(criticalHorseId)~=tonumber(horseId) then return end
    criticalHorseId=nil
    if HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
        FreezeEntityPosition(HorseState.entity,false)
        local maxHp=GetEntityMaxHealth(HorseState.entity)
        SetEntityHealth(HorseState.entity,math.max(1,math.floor(maxHp*((Config.Death.criticalReviveHealth or 28)/100))))
        ClearPedTasks(HorseState.entity)
    end
end)

CreateThread(function()
    while true do
        local horse=HorseState.entity
        Wait((horse~=0 and DoesEntityExist(horse)) and 300 or 1000)
        horse=HorseState.entity
        if horse~=0 and DoesEntityExist(horse) and HorseState.data then
            local hp=GetEntityHealth(horse)
            if (IsEntityDead(horse) or hp<=1) and not criticalHorseId then
                if GetGameTimer()-lastZeroReport>2500 then
                    lastZeroReport=GetGameTimer()
                    -- duas confirmações separadas evitam falso positivo por natives/despawn.
                    TriggerServerEvent('lrrp_stables:criticalHorseV24',HorseState.data.id)
                end
            end

            if criticalHorseId and tonumber(HorseState.data.id)==criticalHorseId then
                local dist=#(GetEntityCoords(PlayerPedId())-GetEntityCoords(horse))
                if dist<=3.0 then
                    TriggerEvent('vorp:TipBottom','[G] Estabilizar cavalo crítico',120)
                    if IsControlJustReleased(0,0x760A9C6F) or IsDisabledControlJustReleased(0,0x760A9C6F) then
                        TriggerServerEvent('lrrp_stables:reviveCriticalHorseV24',criticalHorseId)
                        Wait(1200)
                    end
                end
            end
        else
            -- despawn/local deletion nunca é tratado como morte.
            Wait(750)
        end
    end
end)
