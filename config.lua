Config = {}
Config.Debug = false
Config.MaxHorses = 8
Config.TrainerMaxHorses = 20
Config.TrainerJobs = { horse_trainer = true, trainer = true }
Config.SoloTraining = {
    enabled = true,
    cooldownSeconds = 120,
    rounds = 6,
    minScore = 50,
    xpBase = 18,
    trainingBase = 2,
    staminaCost = 8,
    hungerCost = 3,
    thirstCost = 5,
    disciplineGain = 1
}

Config.TrainerProfession = {
    enabled = true,
    servicePrice = 250,
    trainerPayout = 200,
    currency = 0,
    offerTimeoutSeconds = 30,
    trainingTimeoutSeconds = 120,
    minScore = 50,
    cooldownSeconds = 180,
    xpBonus = 25,
    trainingGain = 5
}
Config.SpawnDistance = 4.0
Config.InteractDistance = 3.0
Config.SaveIntervalMs = 30000
Config.NeedsTickMs = 60000
Config.NeedDecay = { hunger = 1.0, thirst = 1.5, cleanliness = 0.35 }
Config.BaseStats = { health = 100.0, stamina = 100.0, hunger = 100.0, thirst = 100.0, cleanliness = 100.0 }
Config.Actions = {
    pet = { xp = 2, cooldown = 8000 },
    brush = { xp = 4, cleanliness = 28, health = 2, cooldown = 10000 },
    feed = { xp = 5, hunger = 30, health = 4, cooldown = 10000 },
    water = { xp = 5, thirst = 35, stamina = 4, cooldown = 10000 },
    river = { xp = 3, thirst = 45, cooldown = 12000 },
    train = { xp = 12, stamina = 3, cooldown = 30000 }
}
Config.BondingXP = { [0]=0, [1]=0, [2]=100, [3]=300, [4]=700 }
Config.BondingBenefits = {
    [1] = { whistleDistance=35.0, healthBonus=0.0,  staminaBonus=0.0,  actionXpMultiplier=1.00, label='Conhecido' },
    [2] = { whistleDistance=60.0, healthBonus=5.0,  staminaBonus=8.0,  actionXpMultiplier=1.05, label='Confiança' },
    [3] = { whistleDistance=100.0,healthBonus=10.0, staminaBonus=15.0, actionXpMultiplier=1.10, label='Lealdade' },
    [4] = { whistleDistance=160.0,healthBonus=20.0, staminaBonus=25.0, actionXpMultiplier=1.20, label='Vínculo máximo' }
}
Config.StatEvolution = { healthPerBond=0.0, staminaPerBond=0.0, healthPerTraining=0.10, staminaPerTraining=0.18, maxBonus=40.0 }
Config.SalePercent = 0.65
Config.WildHorseSalePrice = 12 -- valor fixo em dólares para cavalos domesticados na natureza

-- v2.2.0: personalidade e temperamento
Config.HorseTemperaments = {
    calm = {
        label='Calmo', description='Mantém a calma com facilidade.',
        followSpeed=1.00, scareChance=0.45, calmTime=0.65, whistleBonus=1.10
    },
    brave = {
        label='Corajoso', description='Resiste melhor a tiros e ameaças.',
        followSpeed=1.05, scareChance=0.30, calmTime=0.70, whistleBonus=1.00
    },
    skittish = {
        label='Arisco', description='Assusta com facilidade, mas melhora muito com vínculo.',
        followSpeed=1.08, scareChance=0.85, calmTime=1.30, whistleBonus=0.90
    },
    stubborn = {
        label='Teimoso', description='Pode demorar a obedecer enquanto o vínculo é baixo.',
        followSpeed=0.90, scareChance=0.55, calmTime=1.05, whistleBonus=0.85
    },
    energetic = {
        label='Energético', description='Responde rápido e gosta de movimento.',
        followSpeed=1.18, scareChance=0.65, calmTime=0.90, whistleBonus=1.05
    }
}
Config.DefaultHorseTemperament = 'calm'

-- v2.5.0: desempenho, logs e proteção de eventos
Config.Performance = {
    debug = false,
    saveStateMinMs = 1800,
    needsTickMinMs = 45000,
    uiRequestMinMs = 500,
    purchaseMinMs = 1500,
    economyActionMinMs = 1000,
    bagOpenMinMs = 700,
    clientIdleHealthMs = 900,
    clientActiveHealthMs = 350
}
Config.TemperamentGunshotRadius = 28.0
Config.TemperamentScareCooldown = 12000

Config.Currency = 0

-- v3.0.3: NPC de suprimentos para cavalos

-- v3.0.5: blips de cavalo
Config.HorseBlips = {
    enabled = true,

    -- Blip preso ao cavalo ativo do jogador.
    activeHorse = {
        enabled = true,
        blipHash = -1230993421,
        name = 'Meu Cavalo'
    },

    -- Blip preso ao NPC da loja de suprimentos.
    supplyNpc = {
        enabled = true,
        blipHash = -1230993421,
        name = 'Suprimentos para Cavalos'
    }
}

Config.SupplyShop = {
    enabled = true,
    interactionControl = 0x760A9C6F, -- G
    interactionDistance = 2.5,
    npcModel = 'U_M_M_ValGenStoreOwner_01',
    shops = {
        { label='Valentine - Suprimentos', coords=vector4(-359.25,781.10,116.26,178.0) },
        { label='Blackwater - Suprimentos', coords=vector4(-880.10,-1366.20,42.53,265.0) },
        { label='Saint Denis - Suprimentos', coords=vector4(2506.70,-1452.10,45.50,90.0) },
        { label='Rhodes - Suprimentos', coords=vector4(1430.10,-1289.50,76.82,85.0) }
    },
    items = {
        { item='water',          label='Água',             icon='💧', price=2,  currency=0, description='Recupera sede do cavalo.' },
        { item='horsemeal',      label='Ração para cavalo',icon='🌾', price=4,  currency=0, description='Recupera fome do cavalo.' },
        { item='horsebrush',     label='Escova',           icon='🧹', price=12, currency=0, description='Usada para limpar o cavalo. Não é consumida.' },
        { item='water_bucket',   label='Balde de água',    icon='🪣', price=8,  currency=0, description='Usado para abastecer água do rancho.' },
        { item='horse_medicine', label='Medicamento',      icon='💊', price=25, currency=0, description='Tratamento e estabilização de emergência.' },
        { item='horseshoe_kit',  label='Kit de ferradura', icon='🧲', price=20, currency=0, description='Usado em serviços de ferrador.' }
    }
}

Config.DefaultStable = vector3(-365.2, 791.4, 116.2)

-- Spawn/câmera de exposição. Coordenadas inspiradas na configuração pública do vorp_stables-lua.
Config.Stables = {
    { name='Valentine', coords=vector3(-365.87,789.51,116.17), radius=3.0, npc=vector4(-365.15,792.68,115.18,178.47), blip=1938782895,
      preview={ spawn=vector4(-366.07,781.81,115.14,5.97), cam=vector3(-367.9267,783.0237,117.7778), camDistance=4.4, camHeight=1.65 } },
    { name='Rhodes', coords=vector3(1432.97,-1295.39,76.82), radius=3.0, npc=vector4(1434.64,-1294.89,76.82,105.08), blip=1938782895,
      preview={ spawn=vector4(1431.56,-1288.21,76.82,87.28), cam=vector3(1431.58,-1292.27,79.0), camDistance=4.4, camHeight=1.65 } },
    { name='Wapiti', coords=vector3(482.06,2215.17,247.16), radius=3.0, npc=vector4(480.43,2213.17,245.90,-44.71), blip=1938782895,
      preview={ spawn=vector4(485.49,2209.0,245.70,-27.54), cam=vector3(483.39,2211.93,248.0), camDistance=4.4, camHeight=1.65 } },
    { name='Blackwater', coords=vector3(-876.57,-1365.10,43.53), radius=3.0, npc=vector4(-878.35,-1364.81,42.53,266.28), blip=1938782895,
      preview={ spawn=vector4(-864.25,-1361.80,42.70,177.48), cam=vector3(-862.6163,-1362.927,45.58158), camDistance=4.4, camHeight=1.65 } },
    { name='Saint Denis', coords=vector3(2510.58,-1456.83,46.31), radius=3.0, npc=vector4(2512.35,-1456.89,45.20,91.68), blip=1938782895,
      preview={ spawn=vector4(2508.59,-1449.96,45.50,90.09), cam=vector3(2506.807,-1452.29,48.61699), camDistance=4.4, camHeight=1.65 } },
    { name='Strawberry', coords=vector3(-1816.81,-561.99,156.07), radius=3.0, npc=vector4(-1818.45,-564.83,155.06,347.22), blip=1938782895,
      preview={ spawn=vector4(-1820.26,-555.84,155.16,163.01), cam=vector3(-1819.512,-558.6999,157.6765), camDistance=4.4, camHeight=1.65 } },
    { name='Tumbleweed', coords=vector3(-5514.24,-3041.81,-2.39), radius=3.0, npc=vector4(-5515.07,-3039.51,-3.39,179.88), blip=1938782895,
      preview={ spawn=vector4(-5519.47,-3039.32,-3.31,181.62), cam=vector3(-5517.651,-3041.113,-0.50949), camDistance=4.4, camHeight=1.65 } }
}

Config.Items = { brush='horsebrush', food='horsemeal', water='water' }
Config.Care = {
    requireItems = true,
    consume = { brush=false, feed=true, water=true },
    labels = { brush='Escova de cavalo', feed='Ração de cavalo', water='Água' }
}
Config.UI = { command='estabulo', openControl=0x760A9C6F, interactionDistance=3.0 }
Config.Inventory = { resource='vorp_inventory', prefix='lrrp_horse', slots=24, weight=120.0 }
Config.Accessories = {
    livePreview=true,
    validateCatalog=true,
    defaultCurrency=0,
    categoryPrices={ saddle=180, blanket=55, saddlebags=95, stirrups=80, bedroll=65, lantern=75, mask=90, mane=40, tail=40 },
    premiumEvery=12,
    premiumGoldPrice=2
}
Config.Showroom = { rotationStep=15.0, zoomStep=0.35, minDistance=2.2, maxDistance=7.0 }


-- v0.5: vendedor, blips, cinematica e upgrades funcionais.
Config.Vendor = {
    enabled = true,
    model = 'U_M_M_ValGenStoreOwner_01',
    scenario = 'WORLD_HUMAN_STAND_WAITING',
    showBlips = true,
    blipName = 'Estábulo',
    interactionDistance = 2.5
}
Config.Cinematic = { enabled=true, fadeOutMs=280, fadeInMs=420, freezePlayer=true }
Config.Performance = { applyMoveRate=true, minMoveRate=0.94, maxMoveRate=1.10 }
Config.Horseshoes = {
    enabled=true,
    levels={
        {level=1,label='Ferradura de Ferro',price=120,currency=0,speed=1,acceleration=1,endurance=2},
        {level=2,label='Ferradura Reforçada',price=280,currency=0,speed=2,acceleration=2,endurance=4},
        {level=3,label='Ferradura de Competição',price=3,currency=1,speed=3,acceleration=3,endurance=6}
    }
}

-- v0.6: criação, saúde, corridas, mercado e propriedades
Config.Breeding = {
    enabled=true, fee=250, currency=0, cooldownHours=48, gestationHours=24,
    minBonding=2, minTraining=5, foalStartHealth=75, foalStartStamina=70
}

-- v2.3.0: ferimentos, tratamento e recuperação
Config.InjurySystem = {
    enabled = true,
    reportDamagePercent = 4, -- só registra queda relevante de vida
    severity = {
        light  = { label='Ferimento leve',    maxHealthPct=75, moveRate=0.96, recoveryMinutes=10, treatmentHealth=82, treatmentStamina=78 },
        leg    = { label='Lesão na perna',    maxHealthPct=50, moveRate=0.86, recoveryMinutes=20, treatmentHealth=72, treatmentStamina=68 },
        severe = { label='Ferimento grave',   maxHealthPct=25, moveRate=0.72, recoveryMinutes=35, treatmentHealth=62, treatmentStamina=58 }
    },
    diseaseRecoveryMinutes = 15,
    recoveryTickSeconds = 30,
    recoveryHealthPerTick = 2,
    recoveryStaminaPerTick = 2
}

Config.HealthSystem = {
    enabled=true,
    vetJobs={ veterinarian=true, vet=true },
    treatmentPrice=90, currency=0,
    diseases={
        colic={label='Cólica',healthPenalty=12,staminaPenalty=8},
        fever={label='Febre',healthPenalty=10,staminaPenalty=12},
        infection={label='Infecção',healthPenalty=15,staminaPenalty=10}
    },
    injuries={
        light={label='Ferimento leve',healthPenalty=8},
        leg={label='Lesão na perna',healthPenalty=12,staminaPenalty=18},
        severe={label='Ferimento grave',healthPenalty=25,staminaPenalty=20}
    }
}
Config.Farrier = {
    jobs={ farrier=true, ferrador=true }, serviceDiscount=0.25
}
Config.Racing = {
    enabled=true, entryFee=25, currency=0, minPlayers=1,
    tracks={
        {key='valentine_sprint',label='Sprint de Valentine',start=vector3(-382.5,797.6,115.7),finish=vector3(-261.0,717.8,113.0),reward=100},
        {key='blackwater_run',label='Corrida de Blackwater',start=vector3(-904.4,-1368.2,43.4),finish=vector3(-742.5,-1240.5,43.5),reward=150}
    }
}
Config.Market = { enabled=true, listingFeePercent=0.03, minPrice=25, maxPrice=100000, defaultCurrency=0 }
Config.PrivateStables = { enabled=true, interactDistance=3.0 }

-- v0.7: rancho, gestação real, genética rara, leilão, pedigree, seguro e campeonatos
Config.Ranch = {
    enabled=true, creationPrice=2500, currency=0, baseCapacity=10,
    upgrades={
        {level=2,label='Rancho Melhorado',price=5000,capacity=16},
        {level=3,label='Centro de Criação',price=9000,capacity=24}
    }
}
Config.Pregnancy = {
    enabled=true, gestationHours=24,
    growth={ newbornHours=6, foalHours=24, juvenileHours=48, adultHours=72 }
}
Config.GeneticsV7 = {
    mutationChance=0.08,
    mutationRange=1,
    rarity={
        {key='common',label='Comum',weight=70,bonus=0},
        {key='uncommon',label='Incomum',weight=20,bonus=1},
        {key='rare',label='Raro',weight=8,bonus=2},
        {key='legendary',label='Lendário',weight=2,bonus=3}
    }
}
Config.Pedigree = { item='horse_pedigree', fee=35, currency=0 }
Config.Insurance = {
    enabled=true, durationHours=168, price=300, currency=0, deductible=100,
    reviveHealth=70, reviveStamina=65
}
Config.Death = {
    permanent=true,
    allowInsuranceClaim=true,
    criticalSeconds=45,       -- tempo para recuperar um cavalo abatido antes da morte
    criticalReviveHealth=28,
    criticalReviveStamina=22,
    criticalItem='horse_medicine',
    requireCriticalItem=true,
    serverConfirmations=2,    -- evita morte permanente por um único save/bug
    confirmationWindowSeconds=12,
    despawnProtectionSeconds=15
}
Config.ProfessionalItems = {
    vet={ item='horse_medicine', amount=1 },
    farrier={ item='horseshoe_kit', amount=1 }
}
Config.Auction = {
    enabled=true, listingFee=50, currency=0, minimumIncrement=25,
    defaultDurationMinutes=60, minDurationMinutes=10, maxDurationMinutes=1440
}
Config.Championship = {
    enabled=true, season='Temporada 1', points={first=10,second=7,third=5,finish=2},
    podiumRewards={ [1]=500,[2]=300,[3]=150 }, currency=0
}

-- v0.8: rancho vivo, empregados, corridas multiplayer, apostas e administração
Config.RanchAutomation = {
    enabled=true,
    stockItem='horsemeal',
    stockPerItem=5,
    waterItem='water_bucket',
    waterPerItem=10,
    maxStock=5000,
    autoCareIntervalMinutes=30,
    feedCostPerHorse=1,
    waterCostPerHorse=1,
    hungerRestore=18,
    thirstRestore=20,
    cleanlinessRestore=10,
    workerHirePrice=350,
    workerMonthlyWage=180,
    billingHours=720,
    maxWorkers=6,
    workerModel='U_M_M_ValGenStoreOwner_01',
    pastureRadius=18.0,
    pastureMaxHorses=6
}
Config.Jockey = {
    jobs={ jockey=true, corredor=true },
    entryDiscount=0.30,
    rewardBonus=0.10
}
Config.MultiplayerRacing = {
    enabled=true,
    minPlayers=2,
    maxPlayers=8,
    entryFee=50,
    currency=0,
    countdownSeconds=5,
    finishTimeoutSeconds=180,
    podiumSplit={0.60,0.30,0.10},
    betting=true,
    minBet=10,
    maxBet=5000,
    houseCut=0.10
}
Config.Trophy = { item='horse_trophy', enabled=true }
Config.LiveAuction = {
    enabled=true,
    npcModel='U_M_M_ValGenStoreOwner_01',
    interactionDistance=3.0
}
Config.Admin = {
    ace='lrrp.stables.admin',
    enabled=true
}


-- v0.9: rancho físico, transporte, cavalos selvagens, corridas avançadas e temporadas automáticas
Config.RanchBuilding = {
    enabled=true,
    maxBuildDistance=45.0,
    structures={
        pasture_fence={label='Cerca de Pastagem',price=450,max=4,capacityBonus=2,prop='p_fence06x'},
        hay_rack={label='Cocho de Feno',price=320,max=2,prop='p_haybale03x'},
        water_trough={label='Bebedouro',price=380,max=2,prop='p_watertrough01x'},
        shelter={label='Abrigo de Cavalos',price=900,max=2,prop='p_hitchingpost01x'},
        training_ring={label='Redondel de Treino',price=1400,max=1,prop='p_hitchingpost01x'}
    }
}
Config.PhysicalStock = {
    enabled=true,
    hayItem='hay_bale',
    waterItem='water_bucket',
    hayUnitsPerItem=10,
    waterUnitsPerItem=10,
    maxStock=5000,
    autoConsumeMinutes=30,
    hungerRestore=12,
    thirstRestore=14
}
Config.HorseTransport = { enabled=true, wagonModel='wagon02x' }
Config.WildHorses = {
    enabled=true,
    tameSteps=6,
    interactionControl=0x760A9C6F, -- G
    interactionDistance=5.0,
    mountTimeoutMs=15000,
    inputTimeoutMs=3500,
    models={
        'A_C_Horse_Mustang_WildBay',
        'A_C_Horse_AmericanPaint_Overo',
        'A_C_Horse_Appaloosa_Leopard',
        'A_C_Horse_KentuckySaddle_Black',
        'A_C_Horse_TennesseeWalker_Chestnut'
    },
    zones={
        {label='Heartlands',coords=vector3(-245.0,760.0,116.0),radius=120.0},
        {label='Big Valley',coords=vector3(-1490.0,250.0,110.0),radius=130.0},
        {label='Great Plains',coords=vector3(-1100.0,-1150.0,66.0),radius=140.0}
    }
}
Config.AdvancedRacing = {
    enabled=true, baseOdds=2.0, spectatorDistance=8.0,
    tracks={
        {key='valentine_sprint',label='Sprint de Valentine',start=vector3(-382.5,797.6,115.7),
         checkpoints={vector3(-350.2,780.4,115.5),vector3(-320.4,758.0,115.0),vector3(-290.0,735.0,114.0)},
         finish=vector3(-261.0,717.8,113.0)},
        {key='blackwater_run',label='Corrida de Blackwater',start=vector3(-904.4,-1368.2,43.4),
         checkpoints={vector3(-862.0,-1340.0,43.5),vector3(-820.0,-1307.0,43.5),vector3(-780.0,-1272.0,43.5)},
         finish=vector3(-742.5,-1240.5,43.5)}
    }
}
Config.Seasons = { automatic=true, prefix='Temporada', durationDays=30 }

-- v1.0.0: release/produção
Config.Release = {
    webhookUrl = '', -- opcional: webhook Discord para auditoria; deixe vazio para desativar
    auditRetentionDays = 90,
    mountedWildTaming = true,
    disciplines = {
        racing   = {label='Corrida',      maxLevel=10,minScore=50,xp=18,trainingGain=3},
        endurance= {label='Resistência',  maxLevel=10,minScore=50,xp=16,trainingGain=3},
        handling = {label='Manejo',       maxLevel=10,minScore=55,xp=16,trainingGain=2},
        barrels  = {label='Tambores',     maxLevel=10,minScore=60,xp=22,trainingGain=4}
    },
    horseshoe = { metersPerDurability=250, maxMetersPerTick=600 },
    structureMaintenance = { enabled=true, maxDurability=100, decayPerCycle=1, cycleHours=24, pricePerPoint=2 }
}
