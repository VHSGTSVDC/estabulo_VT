# Itens usados pela v0.7

Cadastre no seu VORP Inventory os nomes abaixo usando o formato de `items` da sua base:

| name | label sugerido | uso |
|---|---|---|
| `horse_pedigree` | Certificado de Pedigree | documento emitido com metadata do cavalo |
| `horse_medicine` | Medicamento Veterinário | consumido pelo veterinário profissional |
| `horseshoe_kit` | Kit de Ferrador | consumido pelo ferrador profissional |

Os nomes são configuráveis em `config.lua`.

O script usa `getItem`, `subItem` e `addItem` do `vorp_inventory` e verifica falhas antes de continuar o serviço.

## v0.8
- `horse_trophy` — troféu físico com metadata de pista, posição, cavalo e evento.
- `horsemeal` — também pode abastecer o estoque automático do rancho (nome configurável em `Config.RanchAutomation.stockItem`).


## v0.9
- `hay_bale` — fardo de feno usado no estoque físico do rancho.
- `water_bucket` — balde de água usado no estoque físico do rancho.
