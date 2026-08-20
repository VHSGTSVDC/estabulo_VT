# v1.0.7
Correção de saldo específica para a base SERVER_VT enviada.
- consulta `characters.money/gold/rol` como fallback;
- sincroniza o Character quando o snapshot do VORP vier zerado;
- usa `setMoney/setGold/setRol` para aplicar o saldo final;
- adiciona log `PAGAMENTO | live=... banco=...`.
Não requer SQL.
