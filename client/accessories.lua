local accessoryKeys={saddle=true,blanket=true,saddlebags=true,stirrups=true,bedroll=true,lantern=true,mask=true,mane=true,tail=true}
local preview = { key=nil, hash=nil }

AccessoryVisual = {}
function AccessoryVisual.toHash(v)
    if type(v)=='number' then return v end
    if type(v)~='string' or v=='' or v=='0' then return nil end
    return tonumber(v) or tonumber(v:gsub('^0[xX]',''),16)
end
function AccessoryVisual.update(horse)
    if horse and horse~=0 and DoesEntityExist(horse) then Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, 0, 1, 1, 1, 0) end
end
function AccessoryVisual.apply(horse, component)
    component=AccessoryVisual.toHash(component)
    if horse and horse~=0 and DoesEntityExist(horse) and component then
        Citizen.InvokeNative(0xD3A7B003ED343FD9,horse,component,true,true,true); AccessoryVisual.update(horse)
    end
end
function AccessoryVisual.remove(horse, component)
    component=AccessoryVisual.toHash(component)
    if horse and horse~=0 and DoesEntityExist(horse) and component then
        Citizen.InvokeNative(0x0D7FFA1B2F69ED82,horse,component,true,true); AccessoryVisual.update(horse)
    end
end
function AccessoryVisual.applySet(horse,items)
    if not horse or horse==0 or type(items)~='table' then return end
    for key,_ in pairs(accessoryKeys) do if items[key] then AccessoryVisual.apply(horse,items[key]) end end
end

local function equippedHash(key) return HorseState.data and HorseState.data.accessories and HorseState.data.accessories[key] or nil end
local function clearWorldPreview()
    if preview.key and preview.hash and HorseState.entity~=0 and DoesEntityExist(HorseState.entity) then
        AccessoryVisual.remove(HorseState.entity,preview.hash)
        local saved=equippedHash(preview.key); if saved then AccessoryVisual.apply(HorseState.entity,saved) end
    end
    preview.key=nil; preview.hash=nil
end

AddEventHandler('lrrp_stables:applyAccessories',function(horse,items)
    if not horse or horse==0 or not DoesEntityExist(horse) then return end

    -- v3.0.1: aguarda o PED terminar de inicializar antes de aplicar
    -- componentes. Aplicar outfit/componentes cedo demais pode deixar
    -- alguns modelos invisíveis no RedM.
    CreateThread(function()
        local timeout=GetGameTimer()+2500
        while DoesEntityExist(horse) and GetGameTimer()<timeout do
            if IsEntityVisible(horse) and GetEntityAlpha(horse)>0 then break end
            SetEntityVisible(horse,true,false)
            ResetEntityAlpha(horse)
            Wait(100)
        end

        Wait(350)
        if not DoesEntityExist(horse) then return end

        AccessoryVisual.applySet(horse,items)

        -- Força atualização visual depois do último componente.
        Wait(100)
        pcall(function() AccessoryVisual.update(horse) end)
        SetEntityVisible(horse,true,false)
        ResetEntityAlpha(horse)
    end)
end)
RegisterNetEvent('lrrp_stables:previewAccessory',function(key,component)
    if Showroom and Showroom.active then return Showroom.previewAccessory(key,component) end
    if not accessoryKeys[key] or not HorseState.data or not HorseState.near() then return end
    clearWorldPreview(); local current=equippedHash(key); if current then AccessoryVisual.remove(HorseState.entity,current) end
    if component and component~='0' then AccessoryVisual.apply(HorseState.entity,component); preview.key=key; preview.hash=component end
end)
RegisterNetEvent('lrrp_stables:cancelAccessoryPreview',function()
    if Showroom and Showroom.active then Showroom.cancelAccessoryPreview() end
    clearWorldPreview()
end)
RegisterNetEvent('lrrp_stables:equipAccessoryClient',function(key,component)
    if Showroom and Showroom.active then Showroom.commitAccessory(key,component) end
    if not accessoryKeys[key] or not HorseState.data or HorseState.entity==0 or not DoesEntityExist(HorseState.entity) then return end
    clearWorldPreview(); HorseState.data.accessories=HorseState.data.accessories or {}
    local previous=HorseState.data.accessories[key]; if previous then AccessoryVisual.remove(HorseState.entity,previous) end
    if component and component~='0' then HorseState.data.accessories[key]=component; AccessoryVisual.apply(HorseState.entity,component) else HorseState.data.accessories[key]=nil end
end)
AddEventHandler('lrrp_stables:beforeDismiss',clearWorldPreview)
