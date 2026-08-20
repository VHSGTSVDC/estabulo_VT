HorseState={entity=0,data=nil,lastAction={}}
local function requestModel(hash)
    RequestModel(hash); local t=GetGameTimer()+10000
    while not HasModelLoaded(hash) and GetGameTimer()<t do Wait(50) end
    return HasModelLoaded(hash)
end
local function createPlayerHorse(hash,x,y,z,heading)
    -- Usa a mesma estratégia do showroom, que já foi validada nesta base.
    -- O cavalo do dono fica local ao cliente para evitar problemas de net object.
    local horse=CreatePed(hash,x,y,z,heading,false,false,false,false)
    if not horse or horse==0 then
        horse=Citizen.InvokeNative(
            0xD49F9B0955C367DE,
            hash,x,y,z,heading,
            false,false,false,false
        )
    end
    return horse or 0
end

local function findHorseSpawn(player)
    -- Tenta alguns pontos ao redor do jogador. Isso evita o cavalo nascer
    -- dentro de parede/objeto quando o primeiro offset estiver bloqueado.
    local offsets={
        {0.0,  9.0},
        {5.0,  7.0},
        {-5.0, 7.0},
        {0.0, -8.0},
        {7.0,  0.0},
        {-7.0, 0.0}
    }

    for _,off in ipairs(offsets) do
        local c=GetOffsetFromEntityInWorldCoords(player,off[1],off[2],0.8)
        return c.x,c.y,c.z
    end

    local c=GetEntityCoords(player)
    return c.x,c.y,c.z+0.5
end

local function spawnHorseBesidePlayer(hash, player)
    local c=GetOffsetFromEntityInWorldCoords(player,2.5,4.0,0.5)
    local heading=(GetEntityHeading(player)+180.0)%360.0
    local horse=CreatePed(hash,c.x,c.y,c.z,heading,false,false,false,false)
    if not horse or horse==0 then
        horse=Citizen.InvokeNative(0xD49F9B0955C367DE,hash,c.x,c.y,c.z,heading,false,false,false,false)
    end
    return horse or 0
end

function HorseState.spawn(data)
    print(('[estabulo_VT] SPAWN solicitado | id=%s modelo=%s'):format(tostring(data and data.id),tostring(data and data.model)))
    if type(data)~='table' or not data.model then return false end
    if data.death_state=='dead' or data.death_state=='claimable' or data.death_state=='critical' or data.life_stage=='deceased' then
        TriggerEvent('lrrp_stables:notify','Este cavalo está indisponível por morte/estado crítico e não pode ser chamado.')
        return false
    end
    if HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
        if HorseState.data and tonumber(HorseState.data.id)==tonumber(data.id) then
            HorseState.data=data
            return HorseState.call()
        end
        DeleteEntity(HorseState.entity)
        Wait(100)
    end
    HorseState.entity=0
    HorseState.data=nil

    local player=PlayerPedId()
    local hash=joaat(tostring(data.model))
    if not IsModelValid(hash) or not requestModel(hash) then
        print(('[estabulo_VT] ERRO modelo=%s'):format(tostring(data.model)))
        TriggerEvent('lrrp_stables:notify','Não foi possível carregar o cavalo.')
        return false
    end

    local ent=spawnHorseBesidePlayer(hash,player)
    local untilAt=GetGameTimer()+5000
    while ent~=0 and not DoesEntityExist(ent) and GetGameTimer()<untilAt do Wait(0) end

    if ent==0 or not DoesEntityExist(ent) then
        print(('[estabulo_VT] ERRO CreatePed modelo=%s'):format(tostring(data.model)))
        SetModelAsNoLongerNeeded(hash)
        return false
    end

    SetEntityAsMissionEntity(ent,true,true)
    SetEntityVisible(ent,true,false)
    ResetEntityAlpha(ent)
    SetEntityAlpha(ent,255,false)
    SetEntityInvincible(ent,false)
    pcall(function() SetEntityLodDist(ent,500) end)
    SetBlockingOfNonTemporaryEvents(ent,true)
    pcall(function() PlaceEntityOnGroundProperly(ent,true) end)
    pcall(function() Citizen.InvokeNative(0x283978A15512B2FE,ent,true) end)
    pcall(function() Citizen.InvokeNative(0x77FF8D35EEC6BBC4,ent,1,0) end)

    HorseState.entity=ent
    HorseState.data=data
    TriggerEvent('lrrp_stables:updateActiveHorseBlipV305',ent,data)
    HorseState.behavior='idle'
    HorseState.followThread=false
    TriggerServerEvent('lrrp_stables:ensureTemperament',data.id)

    pcall(function()
        local level=math.max(1,math.min(4,tonumber(data.bonding) or LRRP.BondingFromXP(data.xp)))
        local benefit=Config.BondingBenefits[level] or Config.BondingBenefits[1] or {}
        local baseMax=GetEntityMaxHealth(ent)
        if baseMax and baseMax>0 then
            local bonus=tonumber(benefit.healthBonus) or 0
            local newMax=math.floor(baseMax*(1.0+(bonus/100.0)))
            SetEntityMaxHealth(ent,newMax)
            local savedMax=100.0+bonus
            local pct=math.max(1,math.min(savedMax,tonumber(data.health) or 100))/savedMax
            SetEntityHealth(ent,math.max(1,math.floor(newMax*pct)))
        end
    end)

    -- O PED precisa estabilizar antes dos componentes visuais.
    Wait(450)
    SetEntityVisible(ent,true,false)
    ResetEntityAlpha(ent)
    TriggerEvent('lrrp_stables:applyAccessories',ent,data.accessories or {})
    SetModelAsNoLongerNeeded(hash)

    local ec=GetEntityCoords(ent)
    print(('[estabulo_VT] SPAWN OK | entity=%s modelo=%s coords=%.2f %.2f %.2f visible=%s'):format(
        tostring(ent),tostring(data.model),ec.x,ec.y,ec.z,tostring(IsEntityVisible(ent))
    ))
    TriggerEvent('lrrp_stables:notify',('%s apareceu perto de você.'):format(tostring(data.name or 'Seu cavalo')))
    Wait(250)
    HorseState.call()
    return true
end

function HorseState.call()
    if HorseState.entity==0 or not DoesEntityExist(HorseState.entity) then
        print('[estabulo_VT] CHAMAR ERRO | entidade inexistente')
        return false
    end
    local ent=HorseState.entity
    local player=PlayerPedId()
    SetEntityVisible(ent,true,false)
    ResetEntityAlpha(ent)
    SetEntityAlpha(ent,255,false)
    pcall(function() SetEntityLodDist(ent,500) end)
    local dist=#(GetEntityCoords(player)-GetEntityCoords(ent))
    local level=math.max(1,math.min(4,tonumber(HorseState.data and HorseState.data.bonding) or LRRP.BondingFromXP(HorseState.data and HorseState.data.xp)))
    local benefit=Config.BondingBenefits[level] or Config.BondingBenefits[1] or {}
    local whistleDistance=tonumber(benefit.whistleDistance) or 35.0

    print(('[estabulo_VT] CHAMAR | entity=%s distancia=%.2f bonding=%d alcance=%.2f'):format(
        tostring(ent),dist,level,whistleDistance
    ))

    if dist>whistleDistance then
        TriggerEvent('lrrp_stables:notify',('Seu cavalo está longe demais. Bonding %d permite assobiar até %.0fm.'):format(level,whistleDistance))
        return false
    end

    if dist>3.0 then
        ClearPedTasks(ent)
        local speed=3.2+(level*0.35)
        TaskGoToEntity(ent,player,-1,2.0,speed,0.0,0)
    end
    return true
end

function HorseState.dismiss(mode)
    mode=tostring(mode or 'away')
    TriggerEvent('lrrp_stables:beforeDismiss')

    if HorseState.entity~=0 and DoesEntityExist(HorseState.entity) and HorseState.data then
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

        SetEntityAsMissionEntity(HorseState.entity,true,true)
        DeleteEntity(HorseState.entity)

        local tries=0
        while DoesEntityExist(HorseState.entity) and tries<20 do
            Wait(50)
            DeleteEntity(HorseState.entity)
            tries=tries+1
        end
    end

    TriggerEvent('lrrp_stables:removeActiveHorseBlipV305')
    HorseState.entity=0
    HorseState.data=nil
    HorseState.behavior='idle'
    HorseState.followThread=false

    if mode=='stable' then
        TriggerEvent('lrrp_stables:notify','Cavalo guardado no estábulo.')
    else
        TriggerEvent('lrrp_stables:notify','Você mandou o cavalo embora.')
    end
    return true
end

function HorseState.isNearWater()
    if HorseState.entity==0 or not DoesEntityExist(HorseState.entity) then return false end
    if not HorseState.near() then return false end

    local horse=HorseState.entity
    local player=PlayerPedId()

    local ok=false

    -- Água normal / profunda.
    if IsEntityInWater(horse) or IsEntityInWater(player) then ok=true end

    -- Alguns rios rasos não marcam IsEntityInWater de forma consistente.
    if not ok then
        local s1,s2=false,false
        pcall(function() s1=IsPedSwimming(horse) end)
        pcall(function() s2=IsPedSwimming(player) end)
        ok=s1 or s2
    end

    -- Fallback para nível de submersão, útil em margens/água rasa.
    if not ok and GetEntitySubmergedLevel then
        local hLevel,pLevel=0.0,0.0
        pcall(function() hLevel=GetEntitySubmergedLevel(horse) or 0.0 end)
        pcall(function() pLevel=GetEntitySubmergedLevel(player) or 0.0 end)
        ok=(tonumber(hLevel) or 0)>0.02 or (tonumber(pLevel) or 0)>0.02
    end

    return ok
end

function HorseState.near()
    if HorseState.entity==0 or not DoesEntityExist(HorseState.entity) then return false end
    return #(GetEntityCoords(PlayerPedId())-GetEntityCoords(HorseState.entity))<=Config.InteractDistance
end
local function careAnim(action)
    local player=PlayerPedId()
    if action=='pet' then
        -- Contextual petting-style gesture near the horse.
        TaskTurnPedToFaceEntity(player,HorseState.entity,800)
        Wait(500)
        pcall(function()
            Citizen.InvokeNative(0xEA47FE3719165B94,player,'script_common@shared_scenario@player@interaction@horse@pet',-1,0,0,0,0)
        end)
        Wait(1800)
        ClearPedTasks(player)
    elseif action=='brush' then
        TaskTurnPedToFaceEntity(player,HorseState.entity,800)
        Wait(500)
        -- Safe fallback animation: crouched/interaction movement without spawning props.
        TaskStartScenarioInPlace(player,joaat('WORLD_HUMAN_CROUCH_INSPECT'),2200,true,false,false,false)
        Wait(2200)
        ClearPedTasks(player)
    elseif action=='feed' then
        TaskTurnPedToFaceEntity(player,HorseState.entity,700)
        Wait(400)
        TaskStartScenarioInPlace(player,joaat('WORLD_HUMAN_FEED_CHICKEN'),1800,true,false,false,false)
        Wait(1800)
        ClearPedTasks(player)
    elseif action=='water' then
        TaskTurnPedToFaceEntity(player,HorseState.entity,700)
        Wait(400)
        TaskStartScenarioInPlace(player,joaat('WORLD_HUMAN_CROUCH_INSPECT'),1600,true,false,false,false)
        Wait(1600)
        ClearPedTasks(player)
    elseif action=='train' then
        TaskTurnPedToFaceEntity(player,HorseState.entity,700)
        Wait(400)
        TaskStartScenarioInPlace(player,joaat('WORLD_HUMAN_WRITE_NOTEBOOK'),1800,true,false,false,false)
        Wait(1800)
        ClearPedTasks(player)
    end
end

function HorseState.action(name)
    if not HorseState.data or HorseState.entity==0 or not DoesEntityExist(HorseState.entity) then
        return TriggerEvent('lrrp_stables:notify','Chame seu cavalo primeiro.')
    end
    if not HorseState.near() then
        return TriggerEvent('lrrp_stables:notify','Aproxime-se do cavalo para cuidar dele.')
    end

    local a=Config.Actions[name]
    if not a then return end
    local now=GetGameTimer()
    if (HorseState.lastAction[name] or 0)+a.cooldown>now then
        return TriggerEvent('lrrp_stables:notify',Lang.cooldown)
    end

    HorseState.lastAction[name]=now

    if name=='pet' or name=='brush' or name=='feed' or name=='water' or name=='train' then
        CreateThread(function()
            careAnim(name)
            TriggerServerEvent('lrrp_stables:action',HorseState.data.id,name)
        end)
    else
        TriggerServerEvent('lrrp_stables:action',HorseState.data.id,name)
    end
end


-- v2.1.0: comportamento do cavalo
HorseState.behavior = HorseState.behavior or 'idle'
HorseState.followThread = HorseState.followThread or false

local function currentBondingLevel()
    if not HorseState.data then return 1 end
    return math.max(1,math.min(4,tonumber(HorseState.data.bonding) or LRRP.BondingFromXP(HorseState.data.xp)))
end

function HorseState.setBehavior(mode)
    if HorseState.entity==0 or not DoesEntityExist(HorseState.entity) then
        TriggerEvent('lrrp_stables:notify','Chame seu cavalo primeiro.')
        return false
    end

    mode=tostring(mode or 'idle')
    local horse=HorseState.entity
    local player=PlayerPedId()

    if mode=='follow' then
        HorseState.behavior='follow'
        SetBlockingOfNonTemporaryEvents(horse,true)
        ClearPedTasks(horse)

        if not HorseState.followThread then
            HorseState.followThread=true
            CreateThread(function()
                while HorseState.followThread and HorseState.behavior=='follow'
                  and HorseState.entity~=0 and DoesEntityExist(HorseState.entity) do

                    local ent=HorseState.entity
                    local ped=PlayerPedId()
                    local dist=#(GetEntityCoords(ent)-GetEntityCoords(ped))
                    local lvl=currentBondingLevel()

                    -- Quanto maior o vínculo, melhor a resposta e menor a distância de acompanhamento.
                    local desired=3.2
                    local tkey=(HorseState.data and HorseState.data.temperament) or Config.DefaultHorseTemperament or 'calm'
                    local tdef=(Config.HorseTemperaments and Config.HorseTemperaments[tkey]) or {followSpeed=1.0}
                    local speed=(2.8+(lvl*0.40))*(tonumber(tdef.followSpeed) or 1.0)

                    if dist>desired+1.0 then
                        TaskGoToEntity(ent,ped,-1,desired,speed,0.0,0)
                    elseif dist<2.1 then
                        ClearPedTasks(ent)
                        TaskStandStill(ent,900)
                    end

                    Wait(900)
                end
                HorseState.followThread=false
            end)
        end

        TriggerEvent('lrrp_stables:notify',('🐎 %s agora está seguindo você.'):format(
            tostring(HorseState.data and HorseState.data.name or 'Seu cavalo')
        ))
        return true
    end

    -- Qualquer outro modo encerra o loop de seguir.
    HorseState.behavior=mode
    HorseState.followThread=false
    ClearPedTasks(horse)

    if mode=='stay' then
        SetBlockingOfNonTemporaryEvents(horse,true)
        TaskStandStill(horse,-1)
        TriggerEvent('lrrp_stables:notify','✋ Cavalo ficará parado aqui.')
        return true
    elseif mode=='graze' then
        SetBlockingOfNonTemporaryEvents(horse,false)
        TaskWanderStandard(horse,5.0,10)
        TriggerEvent('lrrp_stables:notify','🌿 Cavalo solto para pastar nas proximidades.')
        return true
    end

    return false
end


-- ============================================================
-- v3.0.1 HOTFIX - proteção contra PED de cavalo invisível
-- ============================================================
HorseState.visualRepairAt = HorseState.visualRepairAt or 0
HorseState.visualFailures = HorseState.visualFailures or 0
HorseState.safeRespawning = HorseState.safeRespawning or false

local function horseVisualLooksBroken(ent)
    if not ent or ent==0 or not DoesEntityExist(ent) then return false end

    -- Alpha/visible são os sinais seguros que conseguimos validar via natives.
    if not IsEntityVisible(ent) then return true end
    if GetEntityAlpha(ent)<=10 then return true end

    return false
end

function HorseState.repairVisual(forceRespawn)
    if HorseState.safeRespawning then return false end
    if not HorseState.data then return false end

    local ent=HorseState.entity

    if ent~=0 and DoesEntityExist(ent) and not forceRespawn then
        SetEntityVisible(ent,true,false)
        ResetEntityAlpha(ent)
        SetEntityAlpha(ent,255,false)
        pcall(function() SetEntityLodDist(ent,500) end)
        pcall(function() Citizen.InvokeNative(0x283978A15512B2FE,ent,true) end)

        -- Atualiza outfit/componentes depois de restaurar a entidade.
        TriggerEvent('lrrp_stables:applyAccessories',ent,HorseState.data.accessories or {})

        Wait(350)

        if not horseVisualLooksBroken(ent) then
            HorseState.visualFailures=0
            return true
        end
    end

    -- Fallback: recria SOMENTE o PED local. Não cria cavalo no banco,
    -- stash, ID, XP ou qualquer outro registro.
    HorseState.safeRespawning=true

    local data=HorseState.data
    local old=HorseState.entity

    if old~=0 and DoesEntityExist(old) then
        local player=PlayerPedId()
        if GetMount(player)==old then
            TaskDismountAnimal(player,0,0,0,0,0)
            Wait(500)
        end
        SetEntityAsMissionEntity(old,true,true)
        DeleteEntity(old)
        Wait(250)
    end

    HorseState.entity=0

    local ok=HorseState.spawn(data)
    HorseState.safeRespawning=false

    if ok then
        TriggerEvent('lrrp_stables:notify','🐎 Visual do cavalo restaurado.')
        print(('[estabulo_VT v3.0.1] HOTFIX VISUAL | respawn seguro id=%s'):format(
            tostring(data.id)
        ))
    else
        print(('[estabulo_VT v3.0.1] HOTFIX VISUAL FALHOU | id=%s'):format(
            tostring(data.id)
        ))
    end

    return ok
end

CreateThread(function()
    while true do
        local sleep=1200
        local ent=HorseState.entity

        if ent~=0 and DoesEntityExist(ent) and HorseState.data and not HorseState.safeRespawning then
            sleep=700

            if horseVisualLooksBroken(ent) then
                HorseState.visualFailures=(HorseState.visualFailures or 0)+1

                -- Primeiras tentativas só restauram flags visuais para não
                -- respawnar por um frame transitório de streaming.
                if HorseState.visualFailures<=2 then
                    SetEntityVisible(ent,true,false)
                    ResetEntityAlpha(ent)
                    SetEntityAlpha(ent,255,false)
                    pcall(function() SetEntityLodDist(ent,500) end)
                elseif GetGameTimer()-(HorseState.visualRepairAt or 0)>8000 then
                    HorseState.visualRepairAt=GetGameTimer()
                    HorseState.visualFailures=0
                    HorseState.repairVisual(true)
                end
            else
                HorseState.visualFailures=0
            end
        else
            HorseState.visualFailures=0
        end

        Wait(sleep)
    end
end)

RegisterCommand('corrigircavalo',function()
    if not HorseState.data then
        return TriggerEvent('lrrp_stables:notify','Nenhum cavalo ativo.')
    end
    CreateThread(function()
        HorseState.repairVisual(false)
    end)
end,false)
