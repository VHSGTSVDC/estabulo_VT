Horses=Horses or {}
local function notify(msg)
    TriggerEvent('vorp:TipRight',tostring(msg),4000)
    SendNUIMessage({action='toast',data={message=tostring(msg)}})
end
RegisterNetEvent('lrrp_stables:notify',notify)
RegisterNetEvent('lrrp_stables:horses',function(rows) Horses=rows or {}; TriggerEvent('lrrp_stables:uiHorses', Horses) end)
RegisterNetEvent('lrrp_stables:uiData',function(data) Horses=(data and data.horses) or {}; TriggerEvent('lrrp_stables:uiDataLocal',data or {horses=Horses,ownedAccessories={}}) end)
RegisterNetEvent('lrrp_stables:refresh',function() TriggerServerEvent('lrrp_stables:requestHorses') end)
RegisterNetEvent('lrrp_stables:forceDismiss',function(id) if HorseState.data and tonumber(HorseState.data.id)==tonumber(id) then HorseState.dismiss() end end)
AddEventHandler('vorp:SelectedCharacter',function() Wait(1500); TriggerServerEvent('lrrp_stables:requestHorses') end)
CreateThread(function() Wait(2500); TriggerServerEvent('lrrp_stables:requestHorses') end)

function byId(id) for _,h in ipairs(Horses) do if tonumber(h.id)==tonumber(id) then return h end end end
function primary() for _,h in ipairs(Horses) do if tonumber(h.is_primary)==1 then return h end end return Horses[1] end

RegisterCommand('cavalos',function()
    if #Horses==0 then return notify('Você não possui cavalos.') end
    for _,h in ipairs(Horses) do print(('[LRRP] #%s %s | %s | XP %s | Bond %s%s'):format(h.id,h.name,h.model,h.xp,h.bonding,tonumber(h.is_primary)==1 and ' [PRINCIPAL]' or '')) end
    notify('Lista enviada ao console F8. Use /cavalo ID ou /cavalo para o principal.')
end,false)
RegisterCommand('cavalo',function(_,args)
    local h=args[1] and byId(args[1]) or primary(); if not h then return notify(Lang.noHorse) end
    HorseState.spawn(h)
end,false)
RegisterCommand('cavaloseguir',function() HorseState.setBehavior('follow') end,false)
RegisterCommand('cavaloficar',function() HorseState.setBehavior('stay') end,false)
RegisterCommand('cavalopastar',function() HorseState.setBehavior('graze') end,false)

RegisterCommand('guardarcavalo',function()
    if not HorseState.data then return notify('Nenhum cavalo ativo para guardar.') end
    HorseState.dismiss('stable')
end,false)

RegisterCommand('mandarembora',function()
    if not HorseState.data then return notify('Nenhum cavalo ativo.') end
    HorseState.dismiss('away')
end,false)
RegisterCommand('principalcavalo',function(_,args) if args[1] then TriggerServerEvent('lrrp_stables:setPrimary',tonumber(args[1])) end end,false)
RegisterCommand('acariciar',function() HorseState.action('pet') end,false)
RegisterCommand('escovar',function() HorseState.action('brush') end,false)
RegisterCommand('alimentarcavalo',function() HorseState.action('feed') end,false)
RegisterCommand('aguacavalo',function() HorseState.action('water') end,false)
RegisterCommand('carinhocavalo',function() HorseState.action('pet') end,false)
RegisterCommand('escovarcavalo',function() HorseState.action('brush') end,false)
RegisterCommand('alimentarcavalo',function() HorseState.action('feed') end,false)
RegisterCommand('aguacavalo',function() HorseState.action('water') end,false)

RegisterCommand('beberio',function()
    if not HorseState.data or HorseState.entity==0 or not DoesEntityExist(HorseState.entity) then
        return notify('Chame seu cavalo primeiro.')
    end
    if not HorseState.near() then
        return notify('Aproxime-se do seu cavalo.')
    end
    if HorseState.isNearWater() then
        HorseState.action('river')
    else
        notify('Entre na água do rio com o cavalo ao seu lado e use /beberio.')
    end
end,false)
RegisterCommand('treinarcavalo',function() HorseState.action('train') end,false)
RegisterCommand('alforje',function() if HorseState.data and HorseState.near() then TriggerServerEvent('lrrp_stables:openBag',HorseState.data.id) else notify(Lang.tooFar) end end,false)
RegisterCommand('vendercavalo',function(_,args) if args[1] then TriggerServerEvent('lrrp_stables:sell',tonumber(args[1])) end end,false)
RegisterCommand('transferircavalo',function(_,args) if args[1] and args[2] then TriggerServerEvent('lrrp_stables:transfer',tonumber(args[1]),tonumber(args[2])) end end,false)
RegisterCommand('comprarcavalo',function(_,args) if args[1] then TriggerServerEvent('lrrp_stables:buy',args[1],table.concat(args,' ',2)) end end,false)
RegisterCommand('acessoriocavalo',function(_,args) if args[1] and args[2] then TriggerEvent('lrrp_stables:setAccessoryClient',args[1],tonumber(args[2])) end end,false)


RegisterNetEvent('lrrp_stables:bondingLevelUp',function(data)
    data=data or {}
    local lvl=tonumber(data.level) or 1
    TriggerEvent('lrrp_stables:notify',('🤝 Bonding Nível %d! %s | ❤️ +%s%% | ⚡ +%s%% | 📣 %.0fm'):format(
        lvl,tostring(data.label or ''),tostring(data.healthBonus or 0),tostring(data.staminaBonus or 0),tonumber(data.whistleDistance) or 35
    ))
end)

RegisterNetEvent('lrrp_stables:whistleHorse',function(h)
    if not h then
        return notify('Você não possui um cavalo disponível para chamar.')
    end
    -- Atualiza também a cópia local caso a lista estivesse desatualizada.
    local replaced=false
    for i,row in ipairs(Horses) do
        if tonumber(row.id)==tonumber(h.id) then
            Horses[i]=h
            replaced=true
            break
        end
    end
    if not replaced then Horses[#Horses+1]=h end
    HorseState.spawn(h)
end)

RegisterCommand('testecavalo',function()
    local h=primary()
    if h then
        print(('[estabulo_VT] TESTE LOCAL | id=%s modelo=%s'):format(tostring(h.id),tostring(h.model)))
        HorseState.spawn(h)
    else
        TriggerServerEvent('lrrp_stables:whistleRequest')
    end
end,false)

local function whistleHorse()
    -- Se já há um cavalo ativo, chama o mesmo cavalo.
    if HorseState.entity~=0 and DoesEntityExist(HorseState.entity) and HorseState.data then
        print('[estabulo_VT v1.1.7] ASSOBIO H | chamando cavalo ativo')
        return HorseState.call()
    end

    -- Sem entidade ativa: busca o cavalo principal no servidor/MySQL.
    print('[estabulo_VT v1.1.7] ASSOBIO H | solicitando cavalo principal')
    TriggerServerEvent('lrrp_stables:whistleRequest')
end

RegisterCommand('assobiar',function()
    whistleHorse()
end,false)

-- INPUT_WHISTLE = H no RedM/RDR2.
-- Usamos o controle nativo diretamente porque RegisterKeyMapping
-- não é compatível com a versão/runtime desta base.
local INPUT_WHISTLE = 0x24978A28

CreateThread(function()
    print('[estabulo_VT v1.1.7] TECLA H ATIVA | INPUT_WHISTLE=0x24978A28')
    local cooldown=0

    while true do
        Wait(0)

        -- Evita disparar o assobio do estábulo enquanto o jogador estiver
        -- digitando no pause/menu ou com a NUI do estábulo em foco.
        if not IsPauseMenuActive() then
            if IsControlJustReleased(0,INPUT_WHISTLE) then
                local now=GetGameTimer()
                if now>=cooldown then
                    cooldown=now+1000
                    whistleHorse()
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then HorseState.dismiss() end end)


-- v1.2.2: menu contextual do cavalo no botão direito.
-- Captura tanto controle normal quanto controle já consumido/desabilitado por outro resource.
local INPUT_AIM = 0xF84FA74F
local careContextOpen=false
local careClickCooldown=0

local function horseInteractionDistance()
    if Config.Horse and Config.Horse.interactionDistance then
        return tonumber(Config.Horse.interactionDistance) or 3.0
    end
    return tonumber(Config.InteractDistance) or 3.0
end

local function openHorseCareContext()
    if careContextOpen then return end
    careContextOpen=true

    -- O cursor precisa ficar disponível para clicar nas opções da NUI.
    SetNuiFocus(true,true)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action='horseContext',
        data={
            open=true,
            xp=(HorseState.data and HorseState.data.xp) or 0,
            bonding=(HorseState.data and HorseState.data.bonding) or 0,
            training=(HorseState.data and HorseState.data.training) or 0
        }
    })

    print('[estabulo_VT] MENU CAVALO ABERTO | botão direito')
end

RegisterNetEvent('lrrp_stables:closeHorseCareContext',function()
    careContextOpen=false
    SetNuiFocus(false,false)
    SendNUIMessage({action='horseContext',data={open=false}})
end)

CreateThread(function()
    print(('[estabulo_VT] MENU CAVALO ATIVO | RMB=%s'):format(tostring(INPUT_AIM)))

    while true do
        local sleep=250

        if HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
            local player=PlayerPedId()
            local horse=HorseState.entity
            local dist=#(GetEntityCoords(player)-GetEntityCoords(horse))

            if dist<=horseInteractionDistance() and not StableUI.open then
                sleep=0

                -- Bloqueia o RMB para o jogo/outros menus enquanto estamos perto do NOSSO cavalo.
                DisableControlAction(0,INPUT_AIM,true)

                -- Alguns resources consomem o controle antes. Por isso checamos os dois estados.
                -- Abre ao SOLTAR o botão direito. Isso impede que o mesmo
                -- clique usado para abrir a NUI seja interpretado pelo HTML
                -- como clique fora do menu e feche instantaneamente.
                local released=
                    IsDisabledControlJustReleased(0,INPUT_AIM)
                    or IsControlJustReleased(0,INPUT_AIM)

                if released and not careContextOpen then
                    local now=GetGameTimer()
                    if now>=careClickCooldown then
                        careClickCooldown=now+700
                        openHorseCareContext()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)



RegisterNetEvent('lrrp_stables:transferOffer',function(data)
    if type(data)~='table' or not data.token then return end
    SetNuiFocus(true,true)
    SendNUIMessage({action='horseTransferOffer',data=data})
end)
