-- estabulo_VT v2.5.0 - rate limits e helpers de segurança
LRRPGuard = LRRPGuard or { last={}, locks={} }

local function now()
    return GetGameTimer()
end

function LRRPGuard.allow(src,key,minMs)
    src=tonumber(src) or 0
    key=tostring(key or 'generic')
    minMs=math.max(0,tonumber(minMs) or 0)
    LRRPGuard.last[src]=LRRPGuard.last[src] or {}
    local t=now()
    local prev=LRRPGuard.last[src][key] or 0
    if t-prev<minMs then return false end
    LRRPGuard.last[src][key]=t
    return true
end

function LRRPGuard.lock(src,key,ttlMs)
    src=tonumber(src) or 0
    key=tostring(key or 'generic')
    ttlMs=math.max(100,tonumber(ttlMs) or 1500)
    local id=('%s:%s'):format(src,key)
    local t=now()
    local untilAt=LRRPGuard.locks[id] or 0
    if untilAt>t then return false end
    LRRPGuard.locks[id]=t+ttlMs
    return true
end

function LRRPGuard.unlock(src,key)
    LRRPGuard.locks[('%s:%s'):format(tonumber(src) or 0,tostring(key or 'generic'))]=nil
end

function LRRPGuard.number(v,min,max,default)
    local n=tonumber(v)
    if not n or n~=n or n==math.huge or n==-math.huge then n=tonumber(default) or 0 end
    if min~=nil and n<min then n=min end
    if max~=nil and n>max then n=max end
    return n
end

function LRRPGuard.text(v,maxLen)
    local s=tostring(v or ''):gsub('[%c<>]','')
    return s:sub(1,tonumber(maxLen) or 64)
end

function LRRPGuard.debug(fmt,...)
    if Config.Performance and Config.Performance.debug then
        print(('[estabulo_VT] '..fmt):format(...))
    end
end

AddEventHandler('playerDropped',function()
    local src=source
    LRRPGuard.last[src]=nil
    local prefix=tostring(src)..':'
    for k in pairs(LRRPGuard.locks) do
        if k:sub(1,#prefix)==prefix then LRRPGuard.locks[k]=nil end
    end
end)
