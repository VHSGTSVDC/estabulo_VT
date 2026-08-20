Showroom={active=false,entity=0,cam=0,stableIndex=1,yaw=205.0,distance=4.4,height=1.65,heading=0.0,data=nil,baseAccessories={},preview={}}

local function showroomNotify(msg)
    TriggerEvent('lrrp_stables:notify', tostring(msg))
end

local function requestModel(hash)
    if not hash or hash == 0 then return false end
    if not IsModelValid(hash) then return false end
    RequestModel(hash, false)
    local untilAt=GetGameTimer()+15000
    while not HasModelLoaded(hash) and GetGameTimer()<untilAt do Wait(25) end
    return HasModelLoaded(hash)
end

local function destroyEntity()
    if Showroom.entity~=0 and DoesEntityExist(Showroom.entity) then
        SetEntityAsMissionEntity(Showroom.entity,true,true)
        DeleteEntity(Showroom.entity)
    end
    Showroom.entity=0
end

local function destroyCam()
    if Showroom.cam~=0 and DoesCamExist(Showroom.cam) then
        RenderScriptCams(false,true,250,true,true)
        DestroyCam(Showroom.cam,false)
    end
    Showroom.cam=0
end

local function updateCamera()
    if Showroom.entity==0 or not DoesEntityExist(Showroom.entity) then return end
    if Showroom.cam==0 or not DoesCamExist(Showroom.cam) then Showroom.cam=CreateCam('DEFAULT_SCRIPTED_CAMERA',true) end
    local c=GetEntityCoords(Showroom.entity)
    local r=math.rad(Showroom.yaw)
    local x=c.x+math.cos(r)*Showroom.distance
    local y=c.y+math.sin(r)*Showroom.distance
    SetCamCoord(Showroom.cam,x,y,c.z+Showroom.height)
    PointCamAtCoord(Showroom.cam,c.x,c.y,c.z+1.15)
    SetCamActive(Showroom.cam,true)
    RenderScriptCams(true,true,250,true,true)
end

local function createLocalHorse(hash, spawn)
    -- Primeiro usa o wrapper CFX padrão. Se algum artifact/fork retornar 0,
    -- usa diretamente o native CREATE_PED do RDR3 como fallback.
    local z = (spawn.z or 0.0) + 0.35
    local horse = CreatePed(hash, spawn.x, spawn.y, z, spawn.w or 0.0, false, false, false, false)
    if not horse or horse == 0 then
        horse = Citizen.InvokeNative(0xD49F9B0955C367DE, hash, spawn.x, spawn.y, z, spawn.w or 0.0, false, false, false, false)
    end
    return horse or 0
end

function Showroom.open(stableIndex)
    Showroom.active=true
    Showroom.stableIndex=tonumber(stableIndex) or 1
    local stable=Config.Stables[Showroom.stableIndex] or Config.Stables[1]
    local p=stable.preview or {}
    Showroom.distance=p.camDistance or 4.4
    Showroom.height=p.camHeight or 1.65
    Showroom.yaw=205.0
end

function Showroom.close()
    Showroom.active=false
    Showroom.data=nil
    Showroom.baseAccessories={}
    Showroom.preview={}
    destroyEntity()
    destroyCam()
end

function Showroom.show(data)
    if not Showroom.active or type(data)~='table' or not data.model then return false end
    local stable=Config.Stables[Showroom.stableIndex] or Config.Stables[1]
    local spawn=stable.preview and stable.preview.spawn
    if not spawn then
        showroomNotify('Showroom sem coordenadas configuradas neste estábulo.')
        return false
    end

    destroyEntity()
    local modelName=tostring(data.model)
    local hash=joaat(modelName)
    if not requestModel(hash) then
        showroomNotify(('Modelo de cavalo não carregou: %s'):format(modelName))
        print(('[estabulo_VT] SHOWROOM: modelo inválido/não carregou: %s (%s)'):format(modelName, tostring(hash)))
        return false
    end

    local horse=createLocalHorse(hash,spawn)
    if horse and horse ~= 0 then
        local entityTimeout=GetGameTimer()+3000
        while not DoesEntityExist(horse) and GetGameTimer()<entityTimeout do Wait(0) end
    end
    if horse==0 or not DoesEntityExist(horse) then
        showroomNotify(('Não foi possível criar a visualização de %s.'):format(data.label or modelName))
        print(('[estabulo_VT] SHOWROOM: CreatePed falhou para %s'):format(modelName))
        SetModelAsNoLongerNeeded(hash)
        return false
    end

    SetEntityAsMissionEntity(horse,true,true)
    SetEntityVisible(horse,true)
    SetEntityAlpha(horse,255,false)
    SetEntityInvincible(horse,true)
    SetBlockingOfNonTemporaryEvents(horse,true)
    SetEntityHeading(horse,spawn.w or 0.0)
    -- Coloca no chão depois do spawn para evitar cavalo abaixo/acima do piso.
    pcall(function() PlaceEntityOnGroundProperly(horse, true) end)
    -- Inicializa a variação/outfit do animal; sem isto alguns modelos podem existir mas ficar invisíveis.
    pcall(function() Citizen.InvokeNative(0x283978A15512B2FE, horse, true) end)
    pcall(function() Citizen.InvokeNative(0x77FF8D35EEC6BBC4, horse, 1, 0) end)
    FreezeEntityPosition(horse,true)
    SetModelAsNoLongerNeeded(hash)

    Showroom.entity=horse
    Showroom.heading=spawn.w or 0.0
    Showroom.data=data
    Showroom.baseAccessories={}
    for k,v in pairs(data.accessories or {}) do Showroom.baseAccessories[k]=v end
    if AccessoryVisual and AccessoryVisual.applySet then AccessoryVisual.applySet(horse,Showroom.baseAccessories) end
    -- Na abertura usa a câmera oficial/configurada do estábulo quando disponível.
    local pcfg=stable.preview or {}
    if pcfg.cam then
        if Showroom.cam==0 or not DoesCamExist(Showroom.cam) then Showroom.cam=CreateCam('DEFAULT_SCRIPTED_CAMERA',true) end
        SetCamCoord(Showroom.cam,pcfg.cam.x,pcfg.cam.y,pcfg.cam.z)
        PointCamAtCoord(Showroom.cam,spawn.x,spawn.y,(spawn.z or 0.0)+1.15)
        SetCamActive(Showroom.cam,true)
        RenderScriptCams(true,true,250,true,true)
    else
        updateCamera()
    end
    print(('[estabulo_VT] SHOWROOM OK: %s entity=%s coords=%.2f %.2f %.2f'):format(modelName, tostring(horse), spawn.x, spawn.y, spawn.z))
    return true
end

function Showroom.rotateHorse(delta)
    if Showroom.entity==0 or not DoesEntityExist(Showroom.entity) then return end
    Showroom.heading=(Showroom.heading+(tonumber(delta) or 0))%360.0
    SetEntityHeading(Showroom.entity,Showroom.heading)
end
function Showroom.orbit(delta) Showroom.yaw=(Showroom.yaw+(tonumber(delta) or 0))%360.0; updateCamera() end
function Showroom.zoom(delta)
    Showroom.distance=math.max(Config.Showroom.minDistance,math.min(Config.Showroom.maxDistance,Showroom.distance+(tonumber(delta) or 0)))
    updateCamera()
end
function Showroom.previewAccessory(key,component)
    if Showroom.entity==0 or not DoesEntityExist(Showroom.entity) then return end
    Showroom.cancelAccessoryPreview(key)
    local current=Showroom.baseAccessories[key]
    if current then AccessoryVisual.remove(Showroom.entity,current) end
    if component and component~='0' then AccessoryVisual.apply(Showroom.entity,component); Showroom.preview[key]=component end
end
function Showroom.cancelAccessoryPreview(onlyKey)
    if Showroom.entity==0 or not DoesEntityExist(Showroom.entity) then Showroom.preview={}; return end
    for key,component in pairs(Showroom.preview) do
        if not onlyKey or onlyKey==key then
            AccessoryVisual.remove(Showroom.entity,component)
            local saved=Showroom.baseAccessories[key]
            if saved then AccessoryVisual.apply(Showroom.entity,saved) end
            Showroom.preview[key]=nil
        end
    end
end
function Showroom.commitAccessory(key,component)
    if Showroom.entity==0 or not DoesEntityExist(Showroom.entity) then return end
    Showroom.cancelAccessoryPreview(key)
    local old=Showroom.baseAccessories[key]
    if old then AccessoryVisual.remove(Showroom.entity,old) end
    if component and component~='0' then
        Showroom.baseAccessories[key]=component
        AccessoryVisual.apply(Showroom.entity,component)
    else
        Showroom.baseAccessories[key]=nil
    end
end
AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then Showroom.close() end end)
