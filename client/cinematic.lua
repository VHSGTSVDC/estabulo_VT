StableCinematic={active=false}
function StableCinematic.enter()
    if not (Config.Cinematic and Config.Cinematic.enabled) then return end
    if IsScreenFadedOut() then return end
    DoScreenFadeOut(Config.Cinematic.fadeOutMs or 280)
    local untilAt=GetGameTimer()+1200 while not IsScreenFadedOut() and GetGameTimer()<untilAt do Wait(0) end
    if Config.Cinematic.freezePlayer then FreezeEntityPosition(PlayerPedId(),true) end
    StableCinematic.active=true
end
function StableCinematic.reveal()
    if not (Config.Cinematic and Config.Cinematic.enabled) then return end
    DoScreenFadeIn(Config.Cinematic.fadeInMs or 420)
end
function StableCinematic.exit()
    if not StableCinematic.active then return end
    if Config.Cinematic and Config.Cinematic.enabled then
        DoScreenFadeOut(Config.Cinematic.fadeOutMs or 280); Wait((Config.Cinematic.fadeOutMs or 280)+40)
    end
    FreezeEntityPosition(PlayerPedId(),false); StableCinematic.active=false
    if Config.Cinematic and Config.Cinematic.enabled then DoScreenFadeIn(Config.Cinematic.fadeInMs or 420) end
end
AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then FreezeEntityPosition(PlayerPedId(),false) end end)
