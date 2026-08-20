LRRPV7={data={ranch=nil,pregnancies={},auctions={},championship={},season=''}}
RegisterNetEvent('lrrp_stables:v7DataClient',function(data)
    LRRPV7.data=data or LRRPV7.data
    if StableUI and StableUI.open then SendNUIMessage({action='v7Data',data=LRRPV7.data}) end
end)
RegisterNetEvent('lrrp_stables:refreshV7',function() TriggerServerEvent('lrrp_stables:v7Data') end)
