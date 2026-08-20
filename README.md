# estabulo_VT
Sistema completo de estábulo para RedM + VORP.
# 🐎 estabulo_VT v3.0.5 PUBLIC

**Sistema completo de estábulos para RedM + VORP**  
**Criado por Victor Winchester**

O `estabulo_VT` é um sistema completo de cavalos para servidores RedM utilizando VORP, com foco em persistência, progressão, imersão, cuidados, criação, rancho e gerenciamento avançado dos animais.

## ✨ Principais recursos

- 🐎 Vários cavalos por personagem
- 💾 Persistência completa no MySQL
- 👤 Vinculado a `identifier + charidentifier`
- 🛒 Compra de cavalos macho/fêmea
- 📣 Assobio / chamar cavalo
- 📦 Guardar cavalo
- 🚪 Mandar embora
- 🐎 Seguir / ficar / pastar
- ❤️ Carinho
- 🧹 Escovar
- 🌾 Alimentar
- 💧 Dar água
- 🌊 Beber água em rios
- 🎒 Alforje individual por cavalo
- 🔫 Armas no cavalo
- 🪶 Selas, mantas, alforjes, lanternas, máscaras, crina e cauda
- ⭐ XP
- 🤝 Bonding níveis 1–4
- 🏇 Treinamento solo
- 👨‍🌾 Profissão de treinador
- 📈 Disciplinas e atributos evolutivos
- 🧬 Reprodução
- 👨‍👩‍👧 Pedigree
- 🐴 Crescimento de potros
- 🧬 Genética e raridade
- 🌲 Cavalos selvagens
- 🤠 Doma
- 💵 Venda de cavalos selvagens
- 🧠 Personalidade e temperamento
- 🩺 Ferimentos e recuperação
- 🚑 Estado crítico
- 🛡️ Seguro
- 💀 Morte permanente segura
- 🏡 Rancho
- 👨‍🌾 Tratadores
- 🌾 Estoque de ração
- 💧 Estoque de água
- 🛒 NPC de suprimentos
- 🗺️ Blip do cavalo ativo
- 🗺️ Blip do NPC de suprimentos
- 🖥️ Interface responsiva
- 🔐 Rate limits e proteções anti-exploit
- ⚡ Otimizações de desempenho

## 📦 Requisitos

- RedM
- VORP Core
- VORP Inventory
- oxmysql

## 🛠️ Instalação

1. Coloque a pasta `estabulo_VT` em sua pasta de resources.
2. Execute o SQL único:

```text
sql/SQL_COMPLETA_V3_FINAL.sql
```

3. Garanta esta ordem no `server.cfg`:

```cfg
ensure oxmysql
ensure vorp_core
ensure vorp_inventory
ensure estabulo_VT
```

4. Reinicie o resource:

```text
stop estabulo_VT
refresh
ensure estabulo_VT
```

## ✅ Diagnóstico

No console:

```text
estabulostatus
```

Se estiver tudo correto, o resource informa que o banco e as dependências foram carregados.

## 🛒 Loja de suprimentos

O sistema inclui NPCs que vendem:

- `water`
- `horsemeal`
- `horsebrush`
- `water_bucket`
- `horse_medicine`
- `horseshoe_kit`

Os preços e locais são configuráveis em `config.lua`.

## 🐎 Blips

A versão 3.0.5 possui:

- blip que acompanha o cavalo ativo;
- blip no NPC de suprimentos.

Ambos podem ser configurados em `Config.HorseBlips`.

## 🧰 Configuração

Os principais sistemas podem ser configurados em:

```text
config.lua
```

Para produção, mantenha:

```lua
Config.Performance.debug = false
```

## 📝 Licença

Este projeto é distribuído sob licença MIT.

Consulte:

```text
LICENSE
```

## 👤 Créditos

**estabulo_VT — Criado por Victor Winchester**

Se redistribuir o projeto, mantenha o aviso de copyright e os créditos conforme a licença incluída.
