-- estabulo_VT v1.9.0 - minigame solo
local controls={
    {hash=0xC7B5340A,label='ENTER'},
    {hash=0x8FFC75D6,label='SHIFT'},
    {hash=0x7065027D,label='A'},
    {hash=0xB4E465B4,label='D'},
    {hash=0xD27782E3,label='S'},
    {hash=0x8FD015D8,label='W'}
}

RegisterNetEvent('lrrp_stables:startSoloTrainingClient',function(data)
    if not data or not data.token then return end
    if StableUI and StableUI.open then StableUI.closeMenu() end
    SetNuiFocus(false,false)
    SetNuiFocusKeepInput(false)
    Wait(300)

    local rounds=math.max(3,math.min(10,tonumber(data.rounds) or 6))
    local hits=0
    TriggerEvent('lrrp_stables:notify',('🏇 Treino solo: %s — %s'):format(
        tostring(data.horseName),tostring(data.disciplineLabel)
    ))
    Wait(1000)

    for i=1,rounds do
        local c=controls[math.random(1,#controls)]
        local success=false
        local deadline=GetGameTimer()+3500

        while GetGameTimer()<deadline do
            Wait(0)
            local text=('TREINO %d/%d  |  PRESSIONE [%s]'):format(i,rounds,c.label)
            TriggerEvent('vorp:TipBottom',text,120)
            SetTextScale(0.52,0.52)
            SetTextColor(255,255,255,255)
            SetTextCentre(true)
            DisplayText(CreateVarString(10,'LITERAL_STRING',text),0.50,0.82)
            if IsControlJustPressed(0,c.hash) or IsControlJustReleased(0,c.hash) then
                success=true
                hits=hits+1
                break
            end
        end

        if success then
            TriggerEvent('lrrp_stables:notify','✅ Movimento correto.')
        else
            TriggerEvent('lrrp_stables:notify','❌ Movimento perdido.')
        end
        Wait(300)
    end

    local score=math.floor((hits/rounds)*100)
    TriggerServerEvent('lrrp_stables:finishSoloTraining',data.token,score)
end)
