-- ═══════════════════════════════════════════════════════════════════
--  mrp_gangs — Organizacijos valdymo išplėtimas (rangai, asocijuoti,
--  diplomatija, veiklos žurnalas). Papildo esamą schemą, jos neardo.
--  Šias lenteles/kolonas taip pat automatiškai sukuria server_org.lua,
--  tačiau čia pateikiama rankinei migracijai.
-- ═══════════════════════════════════════════════════════════════════

-- ── fivempro_gangs papildymai (label, emblema, nustatymai) ─────────
ALTER TABLE `fivempro_gangs`
  ADD COLUMN IF NOT EXISTS `label` VARCHAR(64) NULL AFTER `name`,
  ADD COLUMN IF NOT EXISTS `emblem` VARCHAR(255) NULL AFTER `secondary_color_hex`,
  ADD COLUMN IF NOT EXISTS `settings` LONGTEXT NULL AFTER `emblem`;

-- ── Rangai (custom hierarchija su parent_rank_id) ──────────────────
CREATE TABLE IF NOT EXISTS `fivempro_gang_ranks` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `name` VARCHAR(32) NOT NULL,
  `label` VARCHAR(48) NOT NULL,
  `priority` INT NOT NULL DEFAULT 0,
  `parent_rank_id` INT NULL,
  `color` VARCHAR(16) NOT NULL DEFAULT '#64748B',
  `icon` VARCHAR(32) NOT NULL DEFAULT 'user',
  `permissions` LONGTEXT NOT NULL,
  `is_owner_rank` TINYINT(1) NOT NULL DEFAULT 0,
  `can_have_children` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_ranks_gang` (`gang_id`),
  KEY `idx_gang_ranks_parent` (`parent_rank_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── fivempro_gang_members papildymai ───────────────────────────────
ALTER TABLE `fivempro_gang_members`
  ADD COLUMN IF NOT EXISTS `rank_id` INT NULL AFTER `rank`,
  ADD COLUMN IF NOT EXISTS `status` VARCHAR(20) NOT NULL DEFAULT 'active' AFTER `rank_id`,
  ADD COLUMN IF NOT EXISTS `notes` TEXT NULL AFTER `status`,
  ADD COLUMN IF NOT EXISTS `responsibilities` LONGTEXT NULL AFTER `notes`,
  ADD COLUMN IF NOT EXISTS `permission_overrides` LONGTEXT NULL AFTER `responsibilities`,
  ADD COLUMN IF NOT EXISTS `invited_by` VARCHAR(64) NULL AFTER `permission_overrides`,
  ADD COLUMN IF NOT EXISTS `last_active` TIMESTAMP NULL DEFAULT NULL AFTER `invited_by`;

-- ── Asocijuoti civiliai (NĖRA pilni nariai) ────────────────────────
CREATE TABLE IF NOT EXISTS `fivempro_gang_associates` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `associate_type` VARCHAR(32) NOT NULL DEFAULT 'hired',
  `handler_citizenid` VARCHAR(64) NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'active',
  `notes` TEXT NULL,
  `permissions` LONGTEXT NULL,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_gang_associate` (`gang_id`, `citizenid`),
  KEY `idx_gang_associates_cid` (`citizenid`),
  KEY `idx_gang_associates_handler` (`handler_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Diplomatija (gaujų santykiai) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS `fivempro_gang_relations` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `target_gang_id` INT NOT NULL,
  `relation_type` VARCHAR(20) NOT NULL DEFAULT 'neutral',
  `requested_by` VARCHAR(64) NULL,
  `accepted_by` VARCHAR(64) NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'active',
  `note` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_gang_relation` (`gang_id`, `target_gang_id`),
  KEY `idx_gang_relations_target` (`target_gang_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Veiklos žurnalas ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `fivempro_gang_logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `actor_citizenid` VARCHAR(64) NULL,
  `actor_name` VARCHAR(128) NULL,
  `actor_rank` VARCHAR(48) NULL,
  `action` VARCHAR(48) NOT NULL,
  `target_type` VARCHAR(32) NULL,
  `target_id` VARCHAR(64) NULL,
  `old_value` TEXT NULL,
  `new_value` TEXT NULL,
  `metadata` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_logs_gang` (`gang_id`),
  KEY `idx_gang_logs_action` (`action`),
  KEY `idx_gang_logs_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
