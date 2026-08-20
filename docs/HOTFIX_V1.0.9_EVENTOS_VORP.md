# v1.0.9 — Pagamento pela API interna da sua versão do VORP

Problema confirmado:
O objeto retornado através de `exports.vorp_core:GetCore().getUser(...).getUsedCharacter`
mantém campos como `money`, porém métodos como `removeCurrency` não chegam ao resource consumidor.

A versão do `vorp_core` enviada registra em `server/old_api.lua`:

```lua
AddEventHandler('vorp:removeMoney', function(player, typeCash, quantity)
    ...
    used_char.removeCurrency(typeCash, quantity)
end)

AddEventHandler('vorp:addMoney', function(player, typeCash, quantity)
    ...
    used_char.addCurrency(typeCash, quantity)
end)
```

Por isso o estabulo agora usa:
- `TriggerEvent('vorp:removeMoney', src, currency, amount)`
- `TriggerEvent('vorp:addMoney', src, currency, amount)`

Não requer SQL.
