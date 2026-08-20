LRRP = LRRP or {}
function LRRP.Clamp(v, minv, maxv)
    v = tonumber(v) or minv
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end
function LRRP.BondingFromXP(xp)
    xp = math.max(0,tonumber(xp) or 0)
    local lvl = 1
    for i=2,4 do
        if xp >= (tonumber(Config.BondingXP[i]) or math.huge) then lvl=i end
    end
    return lvl
end

function LRRP.BondingProgress(xp)
    xp=math.max(0,tonumber(xp) or 0)
    local lvl=LRRP.BondingFromXP(xp)
    if lvl>=4 then return lvl,100,xp,xp end
    local a=tonumber(Config.BondingXP[lvl]) or 0
    local b=tonumber(Config.BondingXP[lvl+1]) or a+1
    local pct=math.floor(((xp-a)/math.max(1,b-a))*100)
    return lvl,LRRP.Clamp(pct,0,100),a,b
end
function LRRP.SafeJsonDecode(v)
    if not v or v == '' then return {} end
    local ok, out = pcall(json.decode, v)
    return ok and type(out) == 'table' and out or {}
end
function LRRP.SafeJsonEncode(v)
    local ok, out = pcall(json.encode, v or {})
    return ok and out or '{}'
end
