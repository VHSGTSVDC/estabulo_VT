-- estabulo_VT v3.0.3 - loja de suprimentos
local function findItem(itemName)
    for _,it in ipairs(Config.SupplyShop.items or {}) do
        if tostring(it.item)==tostring(itemName) then return it end
    end
    return nil
end

local function inventoryReady()
    return GetResourceState('vorp_inventory')=='started'
end

local function addItem(src,item,amount)
    if not inventoryReady() then return false end
    local ok,res=pcall(function()
        return exports.vorp_inventory:addItem(src,item,amount,{})
    end)
    return ok and res~=false
end

RegisterNetEvent('lrrp_stables:buySupplyItem',function(itemName,amount)
    local src=source
    if not Config.SupplyShop.enabled then return end
    if LRRPGuard and not LRRPGuard.allow(src,'supply_buy',Config.Performance.economyActionMinMs or 1000) then return end

    local item=findItem(itemName)
    if not item then
        return VORPAdapter.notify(src,'Item de suprimento inválido.')
    end

    amount=math.max(1,math.min(25,math.floor(tonumber(amount) or 1)))
    local unitPrice=math.max(0,tonumber(item.price) or 0)
    local total=unitPrice*amount
    local currency=tonumber(item.currency) or 0

    local balance=VORPAdapter.balance(src,currency)
    if (tonumber(balance) or 0)+0.0001<total then
        return VORPAdapter.notify(src,currency==1 and 'Ouro insuficiente.' or 'Dinheiro insuficiente.')
    end

    if not VORPAdapter.removeCurrency(src,currency,total) then
        return VORPAdapter.notify(src,'Não foi possível processar o pagamento.')
    end

    if not addItem(src,item.item,amount) then
        VORPAdapter.addCurrency(src,currency,total)
        return VORPAdapter.notify(src,'Não foi possível adicionar o item. O valor foi devolvido.')
    end

    VORPAdapter.notify(src,('%s %dx %s comprado(s) por $%s.'):format(
        tostring(item.icon or '🛍️'),amount,tostring(item.label),tostring(total)
    ))

    print(('[estabulo_VT v3.0.3] SUPRIMENTO | src=%s item=%s qtd=%s total=%s'):format(
        tostring(src),tostring(item.item),tostring(amount),tostring(total)
    ))
end)
