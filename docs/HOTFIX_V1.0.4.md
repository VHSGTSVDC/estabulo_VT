# v1.0.4 — compatibilidade com o vorp_core enviado

Esta versão foi adaptada ao código real enviado:
`exports.vorp_core:GetCore().getUser(source).getUsedCharacter`.

Saldo:
- dinheiro: `Character.money`
- ouro: `Character.gold`

Cobrança:
- `Character.removeCurrency(0, valor)` para dinheiro
- `Character.removeCurrency(1, valor)` para ouro

Sem State Bag e sem fallback de banco no fluxo de compra.
Não requer SQL.
