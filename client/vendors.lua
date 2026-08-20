local vendors,blips={},{}
local function requestModel(hash)
    RequestModel(hash); local t=GetGameTimer()+10000
    while not HasModelLoaded(hash) and GetGameTimer()<t do Wait(25) end
    return HasModelLoaded(hash)
end
local function addBlip(stable)
    if not (Config.Vendor and Config.Vendor.showBlips) then return end
    local icon=tonumber(stable.blip) or 1938782895
    local b=Citizen.InvokeNative(0x554D9D53F696D002,1664425300,stable.coords.x,stable.coords.y,stable.coords.z)
    if b and b~=0 then
        Citizen.InvokeNative(0x74F74D3207ED525C,b,icon,true)
        Citizen.InvokeNative(0x9CB1A1623062F402,b,Config.Vendor.blipName or stable.name)
        blips[#blips+1]=b
    end
end
CreateThread(function()
    if not (Config.Vendor and Config.Vendor.enabled) then return end
    local model=joaat(Config.Vendor.model or 'U_M_M_ValGenStoreOwner_01')
    if not requestModel(model) then print('[LRRP_Stables] Modelo do vendedor não carregou.') return end
    for i,stable in ipairs(Config.Stables) do
        addBlip(stable)
        local n=stable.npc
        if n then
            local ped=CreatePed(model,n.x,n.y,n.z,n.w,false,false,false,false)
            if (not ped) or ped==0 then
                ped=Citizen.InvokeNative(0xD49F9B0955C367DE,model,n.x,n.y,n.z,n.w,false,false,false,false)
            end
            if ped and ped~=0 and DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped,true,true)
                SetEntityVisible(ped,true)
                SetEntityAlpha(ped,255,false)
                SetEntityInvincible(ped,true)
                SetBlockingOfNonTemporaryEvents(ped,true)
                SetEntityHeading(ped,n.w)
                pcall(function() PlaceEntityOnGroundProperly(ped,true) end)
                pcall(function() Citizen.InvokeNative(0x283978A15512B2FE,ped,true) end)
                Wait(50)
                SetEntityVisible(ped,true)
                ResetEntityAlpha(ped)
                FreezeEntityPosition(ped,true)
                vendors[i]=ped
                print(('[estabulo_VT v1.1.9] NPC VENDA OK | estabulo=%s entity=%s visible=%s'):format(tostring(stable.name),tostring(ped),tostring(IsEntityVisible(ped))))
            else
                print(('[estabulo_VT v1.1.9] NPC VENDA ERRO | estabulo=%s'):format(tostring(stable.name)))
            end
        end
    end
    SetModelAsNoLongerNeeded(model)
end)
AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    for _,p in pairs(vendors) do if DoesEntityExist(p) then DeleteEntity(p) end end
    for _,b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)
