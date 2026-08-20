# v1.0.3 - Correção de dinheiro VORP

- O showroom da v1.0.2 foi mantido.
- Corrigida a prioridade incorreta do State Bag para dinheiro/ouro.
- Agora `Character.money` / `Character.gold` são usados primeiro.
- `Character.removeCurrency(0, valor)` continua sendo a operação oficial de retirada.
- Logs de compra foram adicionados ao console do servidor.
- Não requer migração SQL.
