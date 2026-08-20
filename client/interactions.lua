RegisterNetEvent('lrrp_stables:actionApplied',function(action,state)
    if not HorseState.data then return end
    for k,v in pairs(state or {}) do HorseState.data[k]=v end
    local msg=({pet=Lang.petted,brush=Lang.brushed,feed=Lang.fed,water=Lang.watered,river=Lang.riverDrink,train=Lang.trained})[action]
    if msg then TriggerEvent('lrrp_stables:notify',msg) end
end)

RegisterNetEvent('lrrp_stables:needsUpdated',function(horseId,state)
    if HorseState.data and tonumber(HorseState.data.id)==tonumber(horseId) then
        for k,v in pairs(state or {}) do HorseState.data[k]=v end
        print(('[estabulo_VT] NECESSIDADES | fome=%.1f sede=%.1f limpeza=%.1f'):format(
            tonumber(HorseState.data.hunger) or 0,
            tonumber(HorseState.data.thirst) or 0,
            tonumber(HorseState.data.cleanliness) or 0
        ))
    end
end)

-- Agora o servidor calcula e persiste a queda das necessidades.
CreateThread(function()
    while true do
        Wait(Config.NeedsTickMs)
        if HorseState.data and HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
            TriggerServerEvent('lrrp_stables:needsTick',HorseState.data.id)
        end
    end
end)

-- Persistência periódica de posição e estado local atual.
CreateThread(function()
    while true do
        Wait(Config.SaveIntervalMs)
        if HorseState.data and HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
            local c=GetEntityCoords(HorseState.entity)
            TriggerServerEvent('lrrp_stables:saveState',{
                id=HorseState.data.id,
                health=HorseState.data.health,
                stamina=HorseState.data.stamina,
                hunger=HorseState.data.hunger,
                thirst=HorseState.data.thirst,
                cleanliness=HorseState.data.cleanliness,
                xp=HorseState.data.xp,
                training=HorseState.data.training,
                x=c.x,y=c.y,z=c.z
            })
        end
    end
end)
