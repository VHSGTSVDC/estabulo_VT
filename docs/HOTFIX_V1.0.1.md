# estabulo_VT v1.0.1 HOTFIX

Corrige dois problemas reportados:

1. Showroom sem cavalo:
   - valida modelo;
   - aguarda carregamento por até 15 s;
   - usa CreatePed local e fallback para o native CREATE_PED;
   - reposiciona o cavalo no chão;
   - exibe mensagem e log quando um modelo específico não existir.

2. "Dinheiro insuficiente" com saldo:
   - adapter compatível com getUsedCharacter em tabela/função;
   - aceita money/gold como número, string ou getter;
   - fallback de leitura na tabela characters para forks do VORP;
   - compatibilidade com removeCurrency e setMoney/setGold.

## Diagnóstico
Use `/estabulosaldo` no jogo. O valor mostrado deve ser igual ao saldo em dinheiro/ouro do personagem.

## Resource
O pacote já vem com a pasta `estabulo_VT`. Use:

ensure oxmysql
ensure vorp_core
ensure vorp_inventory
ensure estabulo_VT
