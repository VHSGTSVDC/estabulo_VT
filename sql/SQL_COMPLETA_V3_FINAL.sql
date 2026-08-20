-- ============================================================
-- estabulo_VT v3.0.0 FINAL
-- SQL COMPLETA / ÚNICA
--
-- Execute APENAS ESTE ARQUIVO.
-- Não é necessário executar as migrações v1.x / v2.x separadamente.
--
-- Compatível com:
-- - instalação nova;
-- - atualização de banco existente;
-- - preserva cavalos já cadastrados;
-- - cria tabelas/colunas ausentes;
-- - normaliza campos necessários;
-- - cria índices de desempenho.
-- ============================================================

-- ============================================================
-- estabulo_VT v3.0.0 FINAL
-- Instalação / consolidação segura do banco.
-- Este arquivo NÃO apaga cavalos existentes.
-- Pode ser executado em instalações já atualizadas.
-- ============================================================

CREATE TABLE IF NOT EXISTS `lrrp_horses` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `charidentifier` INT NOT NULL,
  `name` VARCHAR(32) NOT NULL,
  `model` VARCHAR(100) NOT NULL,
  `is_primary` TINYINT NOT NULL DEFAULT 0,
  `price` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `purchase_currency` INT NOT NULL DEFAULT 0,
  `health` DECIMAL(8,2) NOT NULL DEFAULT 100,
  `stamina` DECIMAL(8,2) NOT NULL DEFAULT 100,
  `hunger` DECIMAL(8,2) NOT NULL DEFAULT 100,
  `thirst` DECIMAL(8,2) NOT NULL DEFAULT 100,
  `cleanliness` DECIMAL(8,2) NOT NULL DEFAULT 100,
  `xp` INT NOT NULL DEFAULT 0,
  `bonding` INT NOT NULL DEFAULT 1,
  `training` INT NOT NULL DEFAULT 0,
  `accessories` LONGTEXT NULL,
  `weapon_storage` LONGTEXT NULL,
  `upgrades` LONGTEXT NULL,
  `sex` VARCHAR(8) NOT NULL DEFAULT 'male',
  `birth_at` DATETIME NULL,
  `father_id` INT NULL,
  `mother_id` INT NULL,
  `genetics` LONGTEXT NULL,
  `breeding_cooldown_until` DATETIME NULL,
  `health_state` LONGTEXT NULL,
  `life_stage` VARCHAR(16) NOT NULL DEFAULT 'adult',
  `rarity` VARCHAR(16) NOT NULL DEFAULT 'common',
  `mutation` LONGTEXT NULL,
  `death_state` VARCHAR(16) NOT NULL DEFAULT 'alive',
  `wild_origin` TINYINT NOT NULL DEFAULT 0,
  `tamed_at` DATETIME NULL,
  `transport_state` VARCHAR(24) NOT NULL DEFAULT 'none',
  `disciplines` LONGTEXT NULL,
  `horseshoe_durability` DECIMAL(6,2) NOT NULL DEFAULT 100,
  `temperament` VARCHAR(24) NULL,
  `insurance_until` DATETIME NULL,
  `ranch_id` INT NULL,
  `last_x` DOUBLE NULL,
  `last_y` DOUBLE NULL,
  `last_z` DOUBLE NULL,
  `critical_until` DATETIME NULL,
  `death_confirmations` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);

ALTER TABLE `lrrp_horses`
  ADD COLUMN IF NOT EXISTS `is_primary` TINYINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `price` DECIMAL(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `purchase_currency` INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `health` DECIMAL(8,2) NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS `stamina` DECIMAL(8,2) NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS `hunger` DECIMAL(8,2) NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS `thirst` DECIMAL(8,2) NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS `cleanliness` DECIMAL(8,2) NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS `xp` INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `bonding` INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS `training` INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `accessories` LONGTEXT NULL,
  ADD COLUMN IF NOT EXISTS `weapon_storage` LONGTEXT NULL,
  ADD COLUMN IF NOT EXISTS `upgrades` LONGTEXT NULL,
  ADD COLUMN IF NOT EXISTS `sex` VARCHAR(8) NOT NULL DEFAULT 'male',
  ADD COLUMN IF NOT EXISTS `birth_at` DATETIME NULL,
  ADD COLUMN IF NOT EXISTS `father_id` INT NULL,
  ADD COLUMN IF NOT EXISTS `mother_id` INT NULL,
  ADD COLUMN IF NOT EXISTS `genetics` LONGTEXT NULL,
  ADD COLUMN IF NOT EXISTS `breeding_cooldown_until` DATETIME NULL,
  ADD COLUMN IF NOT EXISTS `health_state` LONGTEXT NULL,
  ADD COLUMN IF NOT EXISTS `life_stage` VARCHAR(16) NOT NULL DEFAULT 'adult',
  ADD COLUMN IF NOT EXISTS `rarity` VARCHAR(16) NOT NULL DEFAULT 'common',
  ADD COLUMN IF NOT EXISTS `mutation` LONGTEXT NULL,
  ADD COLUMN IF NOT EXISTS `death_state` VARCHAR(16) NOT NULL DEFAULT 'alive',
  ADD COLUMN IF NOT EXISTS `wild_origin` TINYINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `tamed_at` DATETIME NULL,
  ADD COLUMN IF NOT EXISTS `transport_state` VARCHAR(24) NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS `disciplines` LONGTEXT NULL,
  ADD COLUMN IF NOT EXISTS `horseshoe_durability` DECIMAL(6,2) NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS `temperament` VARCHAR(24) NULL,
  ADD COLUMN IF NOT EXISTS `insurance_until` DATETIME NULL,
  ADD COLUMN IF NOT EXISTS `ranch_id` INT NULL,
  ADD COLUMN IF NOT EXISTS `last_x` DOUBLE NULL,
  ADD COLUMN IF NOT EXISTS `last_y` DOUBLE NULL,
  ADD COLUMN IF NOT EXISTS `last_z` DOUBLE NULL,
  ADD COLUMN IF NOT EXISTS `critical_until` DATETIME NULL,
  ADD COLUMN IF NOT EXISTS `death_confirmations` INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS `lrrp_stable_accessories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `charidentifier` INT NOT NULL,
  `category` VARCHAR(32) NOT NULL,
  `component_hash` VARCHAR(32) NOT NULL,
  `price_paid` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `currency` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_lrrp_accessory_owner` (`identifier`,`charidentifier`,`category`,`component_hash`)
);

CREATE TABLE IF NOT EXISTS `lrrp_stable_pregnancies` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `charidentifier` INT NOT NULL,
  `mother_id` INT NOT NULL,
  `father_id` INT NOT NULL,
  `foal_name` VARCHAR(32) NOT NULL,
  `finish_at` DATETIME NOT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'pregnant',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `lrrp_ranches` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `charidentifier` INT NOT NULL,
  `name` VARCHAR(80) NOT NULL,
  `level` INT NOT NULL DEFAULT 1,
  `capacity` INT NOT NULL DEFAULT 4,
  `x` DOUBLE NULL,
  `y` DOUBLE NULL,
  `z` DOUBLE NULL,
  `feed_stock` INT NOT NULL DEFAULT 0,
  `water_stock` INT NOT NULL DEFAULT 0,
  `hay_stock` INT NOT NULL DEFAULT 0,
  `pasture_capacity` INT NOT NULL DEFAULT 4,
  `last_auto_care` DATETIME NULL,
  `next_bill_at` DATETIME NULL,
  `operating_debt` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_lrrp_ranch_owner` (`identifier`,`charidentifier`)
);

CREATE TABLE IF NOT EXISTS `lrrp_ranch_workers` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `ranch_id` INT NOT NULL,
  `name` VARCHAR(40) NOT NULL,
  `role` VARCHAR(24) NOT NULL DEFAULT 'caretaker',
  `wage` INT NOT NULL DEFAULT 0,
  `status` VARCHAR(16) NOT NULL DEFAULT 'active',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);

-- Normalização segura de JSON/estados
UPDATE `lrrp_horses` SET `accessories`='{}' WHERE `accessories` IS NULL OR `accessories`='';
UPDATE `lrrp_horses` SET `weapon_storage`='{}' WHERE `weapon_storage` IS NULL OR `weapon_storage`='';
UPDATE `lrrp_horses` SET `upgrades`='{}' WHERE `upgrades` IS NULL OR `upgrades`='';
UPDATE `lrrp_horses` SET `genetics`='{}' WHERE `genetics` IS NULL OR `genetics`='';
UPDATE `lrrp_horses` SET `mutation`='{}' WHERE `mutation` IS NULL OR `mutation`='';
UPDATE `lrrp_horses` SET `health_state`='{}' WHERE `health_state` IS NULL OR `health_state`='';
UPDATE `lrrp_horses` SET `disciplines`='{}' WHERE `disciplines` IS NULL OR `disciplines`='';
UPDATE `lrrp_horses` SET `death_state`='alive' WHERE `death_state` IS NULL OR `death_state`='';
UPDATE `lrrp_horses` SET `life_stage`='adult' WHERE `life_stage` IS NULL OR `life_stage`='';

-- Bonding 1–4 conforme XP atual
UPDATE `lrrp_horses`
SET `bonding` = CASE
  WHEN COALESCE(`xp`,0) >= 700 THEN 4
  WHEN COALESCE(`xp`,0) >= 300 THEN 3
  WHEN COALESCE(`xp`,0) >= 100 THEN 2
  ELSE 1
END
WHERE `death_state` <> 'dead';

-- Índices finais
CREATE INDEX IF NOT EXISTS `idx_lrrp_horses_owner_primary`
ON `lrrp_horses` (`identifier`,`charidentifier`,`is_primary`,`id`);

CREATE INDEX IF NOT EXISTS `idx_lrrp_horses_owner_state`
ON `lrrp_horses` (`identifier`,`charidentifier`,`death_state`);

CREATE INDEX IF NOT EXISTS `idx_lrrp_horses_ranch_state`
ON `lrrp_horses` (`ranch_id`,`death_state`,`life_stage`);

CREATE INDEX IF NOT EXISTS `idx_lrrp_horses_critical`
ON `lrrp_horses` (`death_state`,`critical_until`);

CREATE INDEX IF NOT EXISTS `idx_lrrp_pregnancies_status_finish`
ON `lrrp_stable_pregnancies` (`status`,`finish_at`);

-- FIM
