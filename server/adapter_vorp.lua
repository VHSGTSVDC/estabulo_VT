VorpCore = exports.vorp_core:GetCore()
VORPAdapter = {}

local function safeCall(fn, ...)
    if type(fn) ~= 'function' then return nil, false end
    local ok, value = pcall(fn, ...)
    if not ok then return nil, false end
    return value, true
end

function VORPAdapter.character(src)
    -- Compatibilidade EXATA com o vorp_core enviado pelo usuário:
    -- CoreFunctions.getUser(source) -> user.getUsedCharacter (snapshot)
    local user = VorpCore.getUser(tonumber(src))
    if not user then
        print(('[estabulo_VT] VORP: getUser(%s) retornou nil'):format(tostring(src)))
        return nil
    end

    local c = user.getUsedCharacter
    if type(c) ~= 'table' then
        print(('[estabulo_VT] VORP: getUsedCharacter inválido para src=%s tipo=%s'):format(
            tostring(src), type(c)
        ))
        return nil
    end
    return c
end

function VORPAdapter.identity(src)
    local c = VORPAdapter.character(src)
    if not c then return nil end
    local identifier = c.identifier
    local charId = c.charIdentifier or c.charidentifier or c.charId
    if not identifier or not charId then return nil end
    return tostring(identifier), tonumber(charId), c
end

function VORPAdapter.job(src)
    local c = VORPAdapter.character(src)
    return c and (c.job or c.Job) or nil
end

function VORPAdapter.isTrainer(src)
    return Config.TrainerJobs[VORPAdapter.job(src) or ''] == true
end

local function numericField(c, names)
    for _, name in ipairs(names) do
        local v = c[name]
        if type(v) == 'number' then return v end
        if type(v) == 'string' then
            local cleaned = v:gsub('%s',''):gsub(',','.')
            local n = tonumber(cleaned)
            if n then return n end
        end
        if type(v) == 'function' then
            local out, ok = safeCall(v)
            if ok then
                local n = tonumber(out)
                if n then return n end
            end
        end
    end
    return nil
end


local function databaseBalance(src, currency)
    local c = VORPAdapter.character(src)
    if not c then return nil end
    local identifier = c.identifier
    local charId = c.charIdentifier or c.charidentifier
    if not identifier or not charId then return nil end

    local row = MySQL.single.await(
        'SELECT money,gold,rol FROM characters WHERE identifier=? AND charidentifier=? LIMIT 1',
        { tostring(identifier), tonumber(charId) }
    )
    if not row then return nil end
    currency = tonumber(currency) or 0
    if currency == 1 then return tonumber(row.gold) end
    if currency == 2 then return tonumber(row.rol) end
    return tonumber(row.money)
end

function VORPAdapter.balance(src, currency)
    local c = VORPAdapter.character(src)
    if not c then return 0 end
    currency = tonumber(currency) or 0

    local live
    if currency == 1 then live = tonumber(c.gold)
    elseif currency == 2 then live = tonumber(c.rol)
    else live = tonumber(c.money) end

    local db = databaseBalance(src, currency)

    -- A base enviada usa a tabela characters como persistência da economia.
    -- Preferimos o valor live quando ele é válido/positivo; se o snapshot
    -- retornado pelo Core vier 0/desatualizado, usamos o valor persistido.
    if live and live > 0 then return live end
    return db or live or 0
end

function VORPAdapter.removeCurrency(src, currency, amount)
    currency = tonumber(currency) or 0
    amount = math.max(0, tonumber(amount) or 0)

    local saldo = VORPAdapter.balance(src, currency)

    print(('[estabulo_VT] PAGAMENTO | src=%s moeda=%d saldo=%.2f preco=%.2f metodo=vorp:removeMoney'):format(
        tostring(src), currency, tonumber(saldo) or 0, amount
    ))

    if (tonumber(saldo) or 0) + 0.0001 < amount then
        print(('[estabulo_VT] SALDO INSUFICIENTE REAL | saldo=%.2f preco=%.2f'):format(
            tonumber(saldo) or 0, amount
        ))
        return false
    end

    -- Compatibilidade exata com o vorp_core enviado pelo usuário.
    -- O evento é registrado em server/old_api.lua e executa
    -- used_char.removeCurrency dentro do próprio vorp_core.
    TriggerEvent('vorp:removeMoney', tonumber(src), currency, amount)

    print(('[estabulo_VT] PAGAMENTO ENVIADO AO VORP | evento=vorp:removeMoney | valor=%.2f'):format(amount))
    return true
end

function VORPAdapter.addCurrency(src, currency, amount)
    currency = tonumber(currency) or 0
    amount = math.max(0, tonumber(amount) or 0)

    -- Mesmo caminho interno usado pelo vorp_core enviado.
    TriggerEvent('vorp:addMoney', tonumber(src), currency, amount)

    print(('[estabulo_VT] CRÉDITO ENVIADO AO VORP | evento=vorp:addMoney | valor=%.2f'):format(amount))
    return true
end

function VORPAdapter.removeMoney(src, amount) return VORPAdapter.removeCurrency(src, Config.Currency or 0, amount) end
function VORPAdapter.addMoney(src, amount) return VORPAdapter.addCurrency(src, Config.Currency or 0, amount) end
function VORPAdapter.notify(src, msg) TriggerClientEvent('lrrp_stables:notify', src, tostring(msg)) end
