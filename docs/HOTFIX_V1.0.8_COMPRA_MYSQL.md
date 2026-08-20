# v1.0.8 — Compra + MySQL

O saldo já estava correto na v1.0.7.

Alterações:
- cobrança volta a usar diretamente `Character.removeCurrency`;
- mensagem "sem dinheiro" só aparece se o saldo realmente for menor que o preço;
- INSERT do cavalo é protegido por `pcall`;
- se o INSERT falhar depois da cobrança, o valor é devolvido;
- logs separados para pagamento e erro MySQL;
- nenhuma migração SQL nova é necessária.

Logs esperados:
`PAGAMENTO OK`
`CAVALO COMPRADO OK`

Se houver falha:
`ERRO MYSQL AO COMPRAR CAVALO`
`REFUNDO APÓS ERRO MYSQL`
