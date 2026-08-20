# estabulo_VT v3.0.5 — Public Release

**Criado por Victor Winchester**

Release pública do sistema de estábulos para RedM + VORP. O projeto pode ser usado, modificado e redistribuído conforme a licença `LICENSE`, mantendo o aviso de copyright e permissão.


Sistema completo de estábulo para RedM + VORP.

## Principais sistemas
- vários cavalos por personagem;
- compra macho/fêmea;
- showroom 3D;
- cavalo principal e assobio;
- guardar / mandar embora;
- seguir / ficar / pastar;
- carinho, escova, alimento, água e rios;
- necessidades e persistência;
- acessórios;
- alforje por cavalo integrado ao VORP Inventory;
- XP, treinamento e Bonding níveis 1–4;
- treino solo e treinador profissional;
- venda e transferência;
- reprodução, genética, pedigree e crescimento;
- rancho e tratadores;
- cavalos selvagens, doma e venda fixa;
- personalidade/temperamento;
- ferimentos e recuperação;
- estado crítico, seguro e morte permanente segura;
- otimizações e rate limits no servidor.

## Instalação
Use `INSTALAR_FINAL.txt`.

## Banco
Para instalações atualizadas ou antigas, execute:
`sql/INSTALL_FINAL_V3.sql`

O SQL é aditivo e não remove cavalos existentes.

## Diagnóstico
No console:
`estabulostatus`

## Configuração
Os principais valores continuam em `config.lua`.
`Config.Performance.debug = false` deve permanecer assim em produção.


## Hotfix 3.0.1
Inclui proteção automática contra PED de cavalo invisível e `/corrigircavalo`.


## Interface v3.0.2
Navegação por símbolos, tooltips e layout sem rolagem horizontal.
