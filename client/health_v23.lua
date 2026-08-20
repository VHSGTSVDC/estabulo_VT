-- estabulo_VT v2.3.0 - monitor de dano e penalidades
local lastEntity=0
local lastPct=nil
local lastReport=0

local function state()
    return (HorseState.data and HorseState.data.health_state) or {}
end

local function injuryDef()
    local s=state()
    if type(s)~='table' then return nil,nil end
    local k=s.injury
    return k,k and Config.InjurySystem.severity[k] or nil
end

RegisterNetEvent('lrrp_stables:horseHealthStateV23',function(horseId,newState)
    if HorseState.data and tonumber(HorseState.data.id)==tonumber(horseId) then
        HorseState.data.health_state=type(newState)=='table' and newState or {}
    end
end)

RegisterNetEvent('lrrp_stables:healthStatusClientV23',function(data)
    local s=data.health_state or {}
    local parts={}
    if s.injury then
        local def=Config.InjurySystem.severity[s.injury] or {}
        parts[#parts+1]=def.label or s.injury
    end
    if s.disease then
        local d=Config.HealthSystem.diseases[s.disease] or {}
        parts[#parts+1]=d.label or s.disease
    end

    local condition=#parts>0 and table.concat(parts,' • ') or 'Saudável'
    if s.treated and s.recovery_until then
        condition=condition..' • em recuperação até '..tostring(s.recovery_until)
    end

    TriggerEvent('lrrp_stables:notify',('🩺 %s | ❤️ %.0f | ⚡ %.0f | %s'):format(
        tostring(data.name or 'Cavalo'),
        tonumber(data.health) or 0,
        tonumber(data.stamina) or 0,
        condition
    ))
end)

RegisterCommand('saudecavalo',function()
    if not HorseState.data then
        return TriggerEvent('lrrp_stables:notify','Chame seu cavalo primeiro.')
    end
    TriggerServerEvent('lrrp_stables:healthStatusV23',HorseState.data.id)
end,false)

CreateThread(function()
    while true do
        local horse=HorseState.entity
        Wait((horse~=0 and DoesEntityExist(horse)) and
            (Config.Performance.clientActiveHealthMs or 350) or
            (Config.Performance.clientIdleHealthMs or 900))

        horse=HorseState.entity
        if horse~=0 and DoesEntityExist(horse) and HorseState.data then
            if horse~=lastEntity then
                lastEntity=horse
                lastPct=nil
            end

            local hp=GetEntityHealth(horse)
            local maxHp=GetEntityMaxHealth(horse)
            if maxHp and maxHp>0 then
                local pct=math.max(0,math.min(100,(hp/maxHp)*100))

                if lastPct and (lastPct-pct)>=(Config.InjurySystem.reportDamagePercent or 4)
                   and GetGameTimer()-lastReport>1500 then
                    lastReport=GetGameTimer()
                    TriggerServerEvent('lrrp_stables:reportHorseDamageV23',HorseState.data.id,pct)
                end
                lastPct=pct
            end

            -- Ferimentos reduzem a capacidade de movimento até a recuperação.
            local key,def=injuryDef()
            if def and SetPedMoveRateOverride then
                pcall(function()
                    SetPedMoveRateOverride(horse,tonumber(def.moveRate) or 1.0)
                end)
            elseif SetPedMoveRateOverride then
                pcall(function() SetPedMoveRateOverride(horse,1.0) end)
            end
        else
            lastEntity=0
            lastPct=nil
            Wait(500)
        end
    end
end)
