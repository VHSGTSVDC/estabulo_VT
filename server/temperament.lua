-- estabulo_VT v2.2.0 - personalidade e temperamento
local keys={'calm','brave','skittish','stubborn','energetic'}

local function validTemperament(k)
    return Config.HorseTemperaments and Config.HorseTemperaments[tostring(k or '')] ~= nil
end

local function randomTemperament()
    return keys[math.random(1,#keys)]
end

local function identity(src)
    return VORPAdapter.identity(src)
end

local function owned(src,horseId)
    local identifier,charId=identity(src)
    if not identifier then return nil end
    return DB.single('SELECT * FROM lrrp_horses WHERE id=? AND identifier=? AND charidentifier=?',{
        tonumber(horseId),identifier,charId
    })
end

RegisterNetEvent('lrrp_stables:ensureTemperament',function(horseId)
    local src=source
    local h=owned(src,horseId)
    if not h then return end

    local temperament=tostring(h.temperament or '')
    if not validTemperament(temperament) then
        temperament=randomTemperament()
        DB.update('UPDATE lrrp_horses SET temperament=? WHERE id=?',{temperament,h.id})
    end

    TriggerClientEvent('lrrp_stables:setHorseTemperament',src,h.id,temperament)
end)

RegisterNetEvent('lrrp_stables:getTemperament',function(horseId)
    local src=source
    local h=owned(src,horseId)
    if not h then return end
    local temperament=tostring(h.temperament or Config.DefaultHorseTemperament or 'calm')
    if not validTemperament(temperament) then temperament='calm' end
    TriggerClientEvent('lrrp_stables:showTemperament',src,h.id,temperament)
end)
