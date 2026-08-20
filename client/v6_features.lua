LRRPV6={data={market={},rankings={},tracks={}},race=nil,private={}}
RegisterNetEvent('lrrp_stables:v6DataClient',function(data) LRRPV6.data=data or LRRPV6.data; if StableUI and StableUI.open then SendNUIMessage({action='v6Data',data=LRRPV6.data}); TriggerServerEvent('lrrp_stables:requestUIData') end end)
RegisterNetEvent('lrrp_stables:refreshV6',function() TriggerServerEvent('lrrp_stables:requestUIData'); TriggerServerEvent('lrrp_stables:v6Data'); TriggerServerEvent('lrrp_stables:v7Data') end)

local function trackByKey(key) for _,t in ipairs((Config.Racing and Config.Racing.tracks) or {}) do if t.key==key then return t end end end
RegisterNetEvent('lrrp_stables:startRaceClient',function(trackKey,horseId)
    local track=trackByKey(trackKey); if not track then return end
    local ped=PlayerPedId(); local mount=GetMount(ped)
    if not mount or mount==0 then return TriggerEvent('lrrp_stables:notify','Monte no cavalo antes de iniciar a corrida.') end
    local p=GetEntityCoords(ped); if #(p-track.start)>35.0 then return TriggerEvent('lrrp_stables:notify','Vá até a largada indicada antes de iniciar.') end
    LRRPV6.race={track=track,horseId=horseId,start=GetGameTimer()}; TriggerEvent('lrrp_stables:notify','Corrida iniciada! Vá até a linha de chegada.')
end)

CreateThread(function()
    while true do
        local sleep=1000
        if LRRPV6.race then
            sleep=0; local p=GetEntityCoords(PlayerPedId()); local f=LRRPV6.race.track.finish
            Citizen.InvokeNative(0x2A32FAA57B937173,0x6903B113,f.x,f.y,f.z-0.8,0,0,0,0,0,0,1.1,1.1,1.1,255,255,255,180,false,false,2,false,nil,nil,false)
            if #(p-f)<5.0 then
                local elapsed=GetGameTimer()-LRRPV6.race.start; TriggerServerEvent('lrrp_stables:raceResult',LRRPV6.race.track.key,LRRPV6.race.horseId,elapsed)
                TriggerEvent('lrrp_stables:notify',('Tempo: %.2f s'):format(elapsed/1000)); LRRPV6.race=nil
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('lrrp_stables:openPrivateStable',function(data)
    if type(data)~='table' then return end
    StableUI.openMenu(tonumber(data.stableIndex) or 1)
end)
exports('OpenPrivateStable',function(data) TriggerEvent('lrrp_stables:openPrivateStable',data or {}) end)
