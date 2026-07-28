CREATE TABLE IF NOT EXISTS `mrp_gangs_v2` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL,
  `label` VARCHAR(96) NOT NULL,
  `gang_type` ENUM('street','cartel','mafia','biker','racing') NOT NULL,
  `owner_citizenid` VARCHAR(64) NULL,
  `color_hex` CHAR(7) NOT NULL DEFAULT '#64748B',
  `avatar_url` VARCHAR(512) NULL,
  `reputation` BIGINT NOT NULL DEFAULT 0,
  `level` INT UNSIGNED NOT NULL DEFAULT 1,
  `heat` INT UNSIGNED NOT NULL DEFAULT 0,
  `treasury` BIGINT NOT NULL DEFAULT 0,
  `status` ENUM('active','suspended','archived') NOT NULL DEFAULT 'active',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_mrp_gangs_v2_name` (`name`),
  KEY `idx_mrp_gangs_v2_type_status` (`gang_type`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_members_v2` (
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(128) NOT NULL,
  `role_key` VARCHAR(32) NOT NULL DEFAULT 'member',
  `status` ENUM('active','suspended','inactive') NOT NULL DEFAULT 'active',
  `contribution` BIGINT NOT NULL DEFAULT 0,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen_at` TIMESTAMP NULL,
  PRIMARY KEY (`gang_id`, `citizenid`),
  UNIQUE KEY `ux_mrp_gang_members_v2_citizen` (`citizenid`),
  KEY `idx_mrp_gang_members_v2_status` (`gang_id`, `status`),
  CONSTRAINT `fk_mrp_gang_members_v2_gang`
    FOREIGN KEY (`gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_mission_locks` (
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `run_token` VARCHAR(96) NOT NULL,
  `acquired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`gang_id`),
  UNIQUE KEY `ux_mrp_gang_mission_locks_token` (`run_token`),
  CONSTRAINT `fk_mrp_gang_mission_locks_gang`
    FOREIGN KEY (`gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_mission_runs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `run_token` VARCHAR(96) NOT NULL,
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `mission_key` VARCHAR(64) NOT NULL,
  `difficulty` ENUM('easy','medium','hard','extreme') NOT NULL,
  `state` ENUM('reserved','active','extracting','completed','failed','cancelled') NOT NULL,
  `phase_index` INT UNSIGNED NOT NULL DEFAULT 1,
  `seed` BIGINT UNSIGNED NOT NULL,
  `bucket_id` INT UNSIGNED NOT NULL,
  `leader_citizenid` VARCHAR(64) NOT NULL,
  `site_json` JSON NOT NULL,
  `interior_key` VARCHAR(64) NULL,
  `performance_score` DECIMAL(5,4) NOT NULL DEFAULT 1.0000,
  `failure_reason` VARCHAR(128) NULL,
  `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `finished_at` TIMESTAMP NULL,
  `settled_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_mrp_gang_mission_runs_token` (`run_token`),
  KEY `idx_mrp_gang_mission_runs_gang_state` (`gang_id`, `state`),
  KEY `idx_mrp_gang_mission_runs_started` (`started_at`),
  CONSTRAINT `fk_mrp_gang_mission_runs_gang`
    FOREIGN KEY (`gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_mission_participants` (
  `run_id` BIGINT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(128) NOT NULL,
  `role_key` VARCHAR(32) NOT NULL DEFAULT 'member',
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `left_at` TIMESTAMP NULL,
  `active_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
  `objective_actions` INT UNSIGNED NOT NULL DEFAULT 0,
  `downs` INT UNSIGNED NOT NULL DEFAULT 0,
  `eligible` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`run_id`, `citizenid`),
  KEY `idx_mrp_gang_mission_participants_citizen` (`citizenid`),
  CONSTRAINT `fk_mrp_gang_mission_participants_run`
    FOREIGN KEY (`run_id`) REFERENCES `mrp_gang_mission_runs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_mission_rewards` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `run_id` BIGINT UNSIGNED NOT NULL,
  `settlement_key` VARCHAR(128) NOT NULL,
  `recipient_type` ENUM('player','gang') NOT NULL,
  `recipient_id` VARCHAR(64) NOT NULL,
  `reward_type` ENUM('cash','item','reputation','treasury','substitute') NOT NULL,
  `reward_key` VARCHAR(64) NOT NULL,
  `amount` BIGINT NOT NULL,
  `metadata_json` JSON NULL,
  `delivered_at` TIMESTAMP NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_mrp_gang_mission_rewards_settlement` (`settlement_key`),
  KEY `idx_mrp_gang_mission_rewards_run` (`run_id`),
  KEY `idx_mrp_gang_mission_rewards_recipient` (`recipient_type`, `recipient_id`),
  KEY `idx_mrp_gang_mission_rewards_pending` (`recipient_type`, `recipient_id`, `delivered_at`),
  CONSTRAINT `fk_mrp_gang_mission_rewards_run`
    FOREIGN KEY (`run_id`) REFERENCES `mrp_gang_mission_runs` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_supply_quota` (
  `quota_key` VARCHAR(64) NOT NULL,
  `window_started_at` TIMESTAMP NOT NULL,
  `window_days` INT UNSIGNED NOT NULL,
  `global_cap` INT UNSIGNED NOT NULL,
  `issued_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`quota_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_audit_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` BIGINT UNSIGNED NULL,
  `run_id` BIGINT UNSIGNED NULL,
  `actor_citizenid` VARCHAR(64) NULL,
  `actor_source` INT NULL,
  `action` VARCHAR(64) NOT NULL,
  `target_type` VARCHAR(32) NULL,
  `target_id` VARCHAR(96) NULL,
  `metadata_json` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mrp_gang_audit_log_gang_created` (`gang_id`, `created_at`),
  KEY `idx_mrp_gang_audit_log_run` (`run_id`),
  KEY `idx_mrp_gang_audit_log_action_created` (`action`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_roles_v2` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `role_key` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `priority` INT NOT NULL DEFAULT 0,
  `is_owner` TINYINT(1) NOT NULL DEFAULT 0,
  `permissions_json` JSON NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_mrp_gang_roles_v2_key` (`gang_id`, `role_key`),
  KEY `idx_mrp_gang_roles_v2_priority` (`gang_id`, `priority`),
  CONSTRAINT `fk_mrp_gang_roles_v2_gang`
    FOREIGN KEY (`gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_invites_v2` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `invited_by` VARCHAR(64) NOT NULL,
  `role_key` VARCHAR(32) NOT NULL DEFAULT 'prospect',
  `status` ENUM('pending','accepted','declined','expired','cancelled') NOT NULL DEFAULT 'pending',
  `expires_at` TIMESTAMP NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  KEY `idx_mrp_gang_invites_v2_target` (`citizenid`, `status`, `expires_at`),
  KEY `idx_mrp_gang_invites_v2_gang` (`gang_id`, `status`),
  CONSTRAINT `fk_mrp_gang_invites_v2_gang`
    FOREIGN KEY (`gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_member_responsibilities_v2` (
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `responsibility_key` VARCHAR(32) NOT NULL,
  `assigned_by` VARCHAR(64) NOT NULL,
  `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`gang_id`, `citizenid`, `responsibility_key`),
  CONSTRAINT `fk_mrp_gang_member_responsibilities_v2_member`
    FOREIGN KEY (`gang_id`, `citizenid`)
    REFERENCES `mrp_gang_members_v2` (`gang_id`, `citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_reputation_ledger` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `amount` BIGINT NOT NULL,
  `reason` VARCHAR(64) NOT NULL,
  `reference_type` VARCHAR(32) NULL,
  `reference_id` VARCHAR(96) NULL,
  `actor_citizenid` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mrp_gang_reputation_ledger_gang` (`gang_id`, `created_at`),
  CONSTRAINT `fk_mrp_gang_reputation_ledger_gang`
    FOREIGN KEY (`gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_idempotency` (
  `idempotency_key` VARCHAR(128) NOT NULL,
  `scope` VARCHAR(48) NOT NULL,
  `result_json` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` TIMESTAMP NULL,
  PRIMARY KEY (`idempotency_key`),
  KEY `idx_mrp_gang_idempotency_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_territories` (
  `territory_id` VARCHAR(64) NOT NULL,
  `territory_type` ENUM('gang','pvp','racket') NOT NULL,
  `owner_gang_id` BIGINT UNSIGNED NULL,
  `control_state` ENUM('neutral','controlled','contested','locked') NOT NULL DEFAULT 'neutral',
  `stability` INT UNSIGNED NOT NULL DEFAULT 50,
  `heat` INT UNSIGNED NOT NULL DEFAULT 0,
  `control_version` BIGINT UNSIGNED NOT NULL DEFAULT 1,
  `bonus_json` JSON NULL,
  `controlled_since` TIMESTAMP NULL,
  `locked_until` TIMESTAMP NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`territory_id`),
  KEY `idx_mrp_gang_territories_owner` (`owner_gang_id`, `territory_type`),
  KEY `idx_mrp_gang_territories_state` (`control_state`, `locked_until`),
  CONSTRAINT `fk_mrp_gang_territories_owner`
    FOREIGN KEY (`owner_gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_territory_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `territory_id` VARCHAR(64) NOT NULL,
  `previous_owner_gang_id` BIGINT UNSIGNED NULL,
  `new_owner_gang_id` BIGINT UNSIGNED NULL,
  `reason` VARCHAR(64) NOT NULL,
  `reference_type` VARCHAR(32) NULL,
  `reference_id` VARCHAR(96) NULL,
  `metadata_json` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mrp_gang_territory_history_territory` (`territory_id`, `created_at`),
  KEY `idx_mrp_gang_territory_history_owner` (`new_owner_gang_id`, `created_at`),
  CONSTRAINT `fk_mrp_gang_territory_history_territory`
    FOREIGN KEY (`territory_id`) REFERENCES `mrp_gang_territories` (`territory_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_treaties` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_a_id` BIGINT UNSIGNED NOT NULL,
  `gang_b_id` BIGINT UNSIGNED NOT NULL,
  `treaty_type` ENUM('alliance','neutral','enemy','ceasefire','pact','protection','tribute','temporary_peace') NOT NULL,
  `status` ENUM('pending','active','declined','broken','expired') NOT NULL DEFAULT 'pending',
  `terms_json` JSON NULL,
  `proposed_by_gang_id` BIGINT UNSIGNED NOT NULL,
  `proposed_by_citizenid` VARCHAR(64) NOT NULL,
  `accepted_by_citizenid` VARCHAR(64) NULL,
  `starts_at` TIMESTAMP NULL,
  `expires_at` TIMESTAMP NULL,
  `ended_at` TIMESTAMP NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mrp_gang_treaties_pair` (`gang_a_id`, `gang_b_id`, `status`),
  KEY `idx_mrp_gang_treaties_expiry` (`status`, `expires_at`),
  CONSTRAINT `fk_mrp_gang_treaties_a`
    FOREIGN KEY (`gang_a_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mrp_gang_treaties_b`
    FOREIGN KEY (`gang_b_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_wars` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `attacker_gang_id` BIGINT UNSIGNED NOT NULL,
  `defender_gang_id` BIGINT UNSIGNED NOT NULL,
  `territory_id` VARCHAR(64) NOT NULL,
  `state` ENUM('declared','preparation','active','settlement','completed','cancelled') NOT NULL DEFAULT 'declared',
  `attacker_score` INT NOT NULL DEFAULT 0,
  `defender_score` INT NOT NULL DEFAULT 0,
  `winner_gang_id` BIGINT UNSIGNED NULL,
  `rules_json` JSON NOT NULL,
  `declared_by_citizenid` VARCHAR(64) NOT NULL,
  `preparation_starts_at` TIMESTAMP NULL,
  `active_starts_at` TIMESTAMP NULL,
  `active_ends_at` TIMESTAMP NULL,
  `settled_at` TIMESTAMP NULL,
  `cooldown_until` TIMESTAMP NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mrp_gang_wars_state_time` (`state`, `active_starts_at`, `active_ends_at`),
  KEY `idx_mrp_gang_wars_attacker` (`attacker_gang_id`, `state`),
  KEY `idx_mrp_gang_wars_defender` (`defender_gang_id`, `state`),
  KEY `idx_mrp_gang_wars_territory` (`territory_id`, `state`),
  CONSTRAINT `fk_mrp_gang_wars_attacker`
    FOREIGN KEY (`attacker_gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_mrp_gang_wars_defender`
    FOREIGN KEY (`defender_gang_id`) REFERENCES `mrp_gangs_v2` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_mrp_gang_wars_territory`
    FOREIGN KEY (`territory_id`) REFERENCES `mrp_gang_territories` (`territory_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_war_roster` (
  `war_id` BIGINT UNSIGNED NOT NULL,
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(128) NOT NULL,
  `locked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`war_id`, `citizenid`),
  KEY `idx_mrp_gang_war_roster_gang` (`war_id`, `gang_id`),
  CONSTRAINT `fk_mrp_gang_war_roster_war`
    FOREIGN KEY (`war_id`) REFERENCES `mrp_gang_wars` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_war_objectives` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `war_id` BIGINT UNSIGNED NOT NULL,
  `objective_key` VARCHAR(64) NOT NULL,
  `objective_type` ENUM('domination','escort','intercept','plant','cash_transport') NOT NULL,
  `state` ENUM('pending','active','completed','failed','expired') NOT NULL DEFAULT 'pending',
  `attacker_points` INT NOT NULL DEFAULT 0,
  `defender_points` INT NOT NULL DEFAULT 0,
  `payload_json` JSON NOT NULL,
  `starts_at` TIMESTAMP NULL,
  `ends_at` TIMESTAMP NULL,
  `completed_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_mrp_gang_war_objectives_key` (`war_id`, `objective_key`),
  KEY `idx_mrp_gang_war_objectives_state` (`war_id`, `state`),
  CONSTRAINT `fk_mrp_gang_war_objectives_war`
    FOREIGN KEY (`war_id`) REFERENCES `mrp_gang_wars` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_war_score_ledger` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `war_id` BIGINT UNSIGNED NOT NULL,
  `objective_id` BIGINT UNSIGNED NULL,
  `gang_id` BIGINT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(64) NULL,
  `points` INT NOT NULL,
  `reason` VARCHAR(64) NOT NULL,
  `idempotency_key` VARCHAR(128) NOT NULL,
  `metadata_json` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_mrp_gang_war_score_idempotency` (`idempotency_key`),
  KEY `idx_mrp_gang_war_score_war` (`war_id`, `gang_id`, `created_at`),
  CONSTRAINT `fk_mrp_gang_war_score_war`
    FOREIGN KEY (`war_id`) REFERENCES `mrp_gang_wars` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mrp_gang_war_score_objective`
    FOREIGN KEY (`objective_id`) REFERENCES `mrp_gang_war_objectives` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mrp_gang_admin_settings` (
  `setting_key` VARCHAR(96) NOT NULL,
  `value_json` JSON NOT NULL,
  `updated_by` VARCHAR(64) NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
