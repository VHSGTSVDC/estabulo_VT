-- estabulo_VT v2.2.0 - personalidade e temperamento
local lastScare=0

local function currentTemperament()
    local key=(HorseState.data and HorseState.data.temperament) or Config.DefaultHorseTemperament or 'calm'
    return key,Config.HorseTemperaments[key] or Config.HorseTemperaments.calm
end

local function bonding()
    if not HorseState.data then return 1 end
    return math.max(1,math.min(4,tonumber(HorseState.data.bonding) or LRRP.BondingFromXP(HorseState.data.xp)))
end

RegisterNetEvent('lrrp_stables:setHorseTemperament',function(horseId,key)
    if HorseState.data and tonumber(HorseState.data.id)==tonumber(horseId) then
        HorseState.data.temperament=tostring(key)
    end
end)

RegisterNetEvent('lrrp_stables:showTemperament',function(horseId,key)
    local def=Config.HorseTemperaments[tostring(key)] or Config.HorseTemperaments.calm
    TriggerEvent('lrrp_stables:notify',('🐎 Temperamento: %s — %s'):format(def.label,def.description))
end)

CreateThread(function()
    while true do
        Wait(350)

        if HorseState.entity~=0 and DoesEntityExist(HorseState.entity) and HorseState.data then
            if not HorseState.data.temperament then
                TriggerServerEvent('lrrp_stables:ensureTemperament',HorseState.data.id)
                Wait(2500)
            end

            local horse=HorseState.entity
            local p=PlayerPedId()
            local dist=#(GetEntityCoords(horse)-GetEntityCoords(p))

            -- Detecta disparo do dono próximo ao cavalo.
            if dist<=(Config.TemperamentGunshotRadius or 28.0)
              and IsPedShooting(p)
              and GetGameTimer()-lastScare>(Config.TemperamentScareCooldown or 12000) then

                lastScare=GetGameTimer()
                local key,def=currentTemperament()
                local lvl=bonding()

                -- Bonding reduz até 60% da chance de susto no nível 4.
                local bondReduction=1.0-((lvl-1)*0.20)
                local chance=math.max(0.05,math.min(0.95,(def.scareChance or .5)*bondReduction))

                if math.random()<chance then
                    ClearPedTasks(horse)

                    if key=='skittish' and lvl<=2 then
                        TaskSmartFleePed(horse,p,18.0,3500,2.0,0)
                        TriggerEvent('lrrp_stables:notify','🐎 Seu cavalo arisco se afastou com o disparo.')
                    else
                        TaskStandStill(horse,math.floor(1200*(def.calmTime or 1.0)))
                        TriggerEvent('lrrp_stables:notify','🐎 Seu cavalo se assustou, mas está tentando se acalmar.')
                    end
                end
            end
        end
    end
end)

RegisterCommand('temperamentocavalo',function()
    if not HorseState.data then
        return TriggerEvent('lrrp_stables:notify','Chame seu cavalo primeiro.')
    end
    TriggerServerEvent('lrrp_stables:getTemperament',HorseState.data.id)
end,false)
