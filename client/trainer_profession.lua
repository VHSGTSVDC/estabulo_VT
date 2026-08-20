-- estabulo_VT v1.8.0 - treinador profissional client
local pendingOffer=nil

RegisterNetEvent('lrrp_stables:trainerServiceOffer',function(data)
    pendingOffer=data
    SetNuiFocus(true,true)
    SendNUIMessage({action='trainerOffer',data=data})
end)

RegisterNUICallback('trainerReply',function(data,cb)
    SetNuiFocus(false,false)
    TriggerServerEvent('lrrp_stables:trainerServiceReply',tostring(data.token or ''),data.accepted==true)
    pendingOffer=nil
    cb({ok=true})
end)

local controls={
    {hash=0xC7B5340A,label='ENTER'},
    {hash=0x8FFC75D6,label='SHIFT'},
    {hash=0x7065027D,label='A'},
    {hash=0xB4E465B4,label='D'}
}

RegisterNetEvent('lrrp_stables:startProfessionalTraining',function(data)
    if not data or not data.token then return end
    SetNuiFocus(false,false)

    local rounds=math.max(3,math.min(10,tonumber(data.rounds) or 6))
    local score=0

    TriggerEvent('lrrp_stables:notify',('Treinando %s em %s. Prepare-se!'):format(
        tostring(data.horseName or 'cavalo'),tostring(data.disciplineLabel or data.discipline)
    ))

    Wait(1200)

    for i=1,rounds do
        local c=controls[math.random(1,#controls)]
        local success=false
        local deadline=GetGameTimer()+2200

        while GetGameTimer()<deadline do
            Wait(0)
            TriggerEvent('vorp:TipBottom',('Treino %d/%d • pressione %s'):format(i,rounds,c.label),100)
            if IsControlJustReleased(0,c.hash) then
                success=true
                break
            end
        end

        if success then
            score=score+math.floor(100/rounds)
            TriggerEvent('lrrp_stables:notify','✅ Movimento correto.')
        else
            TriggerEvent('lrrp_stables:notify','❌ Movimento perdido.')
        end
        Wait(350)
    end

    TriggerServerEvent('lrrp_stables:completeProfessionalTraining',data.token,math.min(100,score))
end)
