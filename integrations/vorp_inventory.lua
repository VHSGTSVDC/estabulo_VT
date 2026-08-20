HorseInventory = {}

local function ready()
    return GetResourceState(Config.Inventory.resource) == 'started'
end

function HorseInventory.id(horseId)
    return ('%s_%s'):format(Config.Inventory.prefix, tostring(horseId))
end

local function registerBag(invId, horseId, horseName)
    exports.vorp_inventory:registerInventory({
        id = invId,
        name = ('Alforje - %s'):format(horseName or ('Cavalo #' .. tostring(horseId))),
        limit = Config.Inventory.weight,
        acceptWeapons = true,

        -- O ID já é exclusivo por cavalo, portanto o inventário pode ser
        -- compartilhado internamente sem misturar cavalos.
        shared = true,

        ignoreItemStackLimit = false,
        whitelistItems = false,

        -- IMPORTANTE:
        -- A versão do vorp_inventory desta base possui um bug em
        -- ADD_CHAR_ID_PERMISSION_MOVE_TO/TAKE_FROM: a função retorna antes
        -- de gravar a permissão. Isso faz o stash abrir mas bloqueia arrastar.
        --
        -- A propriedade do cavalo já é validada no server/main.lua antes
        -- de chegar aqui, então desabilitamos somente a camada defeituosa.
        UsePermissions = false,

        UseBlackList = false,
        whitelistWeapons = false,
        webhook = ''
    })

    exports.vorp_inventory:updateCustomInventorySlots(invId, tonumber(Config.Inventory.slots) or 24)
end

function HorseInventory.ensure(horseId, charId, horseName)
    if not ready() then
        return false, Lang.inventoryUnavailable
    end

    local invId = HorseInventory.id(horseId)

    -- Inventários criados por versões anteriores podem continuar na cache do
    -- vorp_inventory com UsePermissions=true mesmo após reiniciar estabulo_VT.
    -- removeInventory remove apenas a instância da sessão/cache, NÃO apaga
    -- os itens persistidos no banco. Em seguida registramos novamente com
    -- a configuração corrigida e o VORP recarrega o conteúdo do banco.
    local registered = exports.vorp_inventory:isCustomInventoryRegistered(invId)

    if registered then
        local ok,data = pcall(function()
            return exports.vorp_inventory:getCustomInventoryData(invId)
        end)

        local needsRefresh = true
        if ok and type(data)=='table' then
            local perm = data.UsePermissions
            if perm == false then
                needsRefresh = false
            end
        end

        if needsRefresh then
            pcall(function()
                exports.vorp_inventory:removeInventory(invId)
            end)
            registered = false
            print(('[estabulo_VT] ALFORJE CACHE ATUALIZADA | id=%s'):format(invId))
        end
    end

    if not registered then
        registerBag(invId, horseId, horseName)
        print(('[estabulo_VT] ALFORJE REGISTRADO | id=%s | permissoes=false'):format(invId))
    else
        exports.vorp_inventory:updateCustomInventorySlots(invId, tonumber(Config.Inventory.slots) or 24)
    end

    return true, invId
end

function HorseInventory.open(src, horseId, charId, horseName)
    local ok, invId = HorseInventory.ensure(horseId, charId, horseName)
    if not ok then
        return false, invId
    end

    -- Fecha qualquer inventário anterior que tenha ficado em sessão.
    pcall(function()
        exports.vorp_inventory:closeInventory(src)
    end)

    Wait(50)

    exports.vorp_inventory:openInventory(src, invId)

    print(('[estabulo_VT] ALFORJE ABERTO | src=%s cavalo=%s inv=%s'):format(
        tostring(src), tostring(horseId), tostring(invId)
    ))

    return true, invId
end

function HorseInventory.transfer(horseId, oldCharId, newCharId, horseName)
    if not ready() then return end

    -- O stash é identificado pelo ID do cavalo e acompanha o animal.
    -- A autorização para abrir continua sendo feita por getOwned() no
    -- estabulo_VT, então não precisamos alterar permissões internas quebradas.
    local ok, invId = HorseInventory.ensure(horseId, newCharId, horseName)
    if ok then
        print(('[estabulo_VT] ALFORJE TRANSFERIDO | cavalo=%s inv=%s'):format(
            tostring(horseId), tostring(invId)
        ))
    end
end

function HorseInventory.delete(horseId)
    if not ready() then return end
    local invId = HorseInventory.id(horseId)

    if exports.vorp_inventory:isCustomInventoryRegistered(invId) then
        exports.vorp_inventory:deleteCustomInventory(invId)
    end
end
