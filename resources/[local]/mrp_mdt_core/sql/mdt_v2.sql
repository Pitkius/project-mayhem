-- MDT V2 schema (also applied via MySQL.ready in server/main.lua)
-- Phase 1: incidents, timeline, audit, parties/vehicles
-- Phase 3: officers + police case extension (report / force / tools / seized / refs)
-- Phase 4: EMS medical case (medical / meds / actions / equipment)
-- Phase 5: Mechanic repair case (mechanic / diagnostics / work / parts)
-- Phase 6: Evidence locker (mdt_evidence_items)
-- Charset: utf8mb4
-- Core fields are normalized columns — payload JSON is extras only.

CREATE TABLE IF NOT EXISTS `mdt_incidents` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `public_number` VARCHAR(32) NOT NULL,
    `type` ENUM('police','ems','mechanic','fire','civil','other') NOT NULL DEFAULT 'other',
    `status` VARCHAR(32) NOT NULL DEFAULT 'created',
    `priority` TINYINT NOT NULL DEFAULT 2,
    `service_job` VARCHAR(32) NULL,
    `summary` VARCHAR(512) NULL,
    `location_label` VARCHAR(255) NULL,
    `location_x` DOUBLE NULL,
    `location_y` DOUBLE NULL,
    `location_z` DOUBLE NULL,
    `created_by` VARCHAR(64) NULL,
    `assigned_crew` VARCHAR(64) NULL,
    `dispatch_call_id` VARCHAR(32) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_public_number` (`public_number`),
    KEY `idx_status` (`status`),
    KEY `idx_type` (`type`),
    KEY `idx_service_job` (`service_job`),
    KEY `idx_dispatch_call` (`dispatch_call_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_incident_timeline` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `event_type` VARCHAR(64) NOT NULL,
    `actor_citizenid` VARCHAR(64) NULL,
    `actor_name` VARCHAR(128) NULL,
    `payload` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_event_type` (`event_type`),
    KEY `idx_created_at` (`created_at`),
    CONSTRAINT `fk_timeline_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_audit_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `actor_citizenid` VARCHAR(64) NULL,
    `action` VARCHAR(64) NOT NULL,
    `resource` VARCHAR(64) NULL,
    `target` VARCHAR(128) NULL,
    `meta` JSON NULL,
    `ip` VARCHAR(64) NULL,
    `source` INT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_action` (`action`),
    KEY `idx_actor` (`actor_citizenid`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_incident_parties` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `citizenid` VARCHAR(64) NULL,
    `role` VARCHAR(32) NOT NULL DEFAULT 'subject',
    `display_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_citizenid` (`citizenid`),
    CONSTRAINT `fk_parties_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_incident_vehicles` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `plate` VARCHAR(16) NULL,
    `vin` VARCHAR(64) NULL,
    `model` VARCHAR(64) NULL,
    `role` VARCHAR(32) NOT NULL DEFAULT 'involved',
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_plate` (`plate`),
    CONSTRAINT `fk_vehicles_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Phase 4 -------------------------------------------------------------------

-- EMS medical case extension: one row per ems incident.
CREATE TABLE IF NOT EXISTS `mdt_incident_medical` (
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `presentation_code` VARCHAR(64) NULL,
    `presentation_label` VARCHAR(255) NULL,
    `disposition` VARCHAR(32) NOT NULL DEFAULT 'pending',
    `lead_medic_citizenid` VARCHAR(64) NULL,
    `lead_callsign` VARCHAR(16) NULL,
    `facility` VARCHAR(64) NULL,
    `triage_level` VARCHAR(16) NOT NULL DEFAULT 'green',
    `transported` TINYINT(1) NOT NULL DEFAULT 0,
    `invoice_total` INT NOT NULL DEFAULT 0,
    `pulse` SMALLINT NULL,
    `bp_systolic` SMALLINT NULL,
    `bp_diastolic` SMALLINT NULL,
    `resp_rate` SMALLINT NULL,
    `spo2` SMALLINT NULL,
    `gcs` TINYINT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`incident_id`),
    KEY `idx_disposition` (`disposition`),
    KEY `idx_triage` (`triage_level`),
    KEY `idx_lead_medic` (`lead_medic_citizenid`),
    CONSTRAINT `fk_medical_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Medications administered on scene.
CREATE TABLE IF NOT EXISTS `mdt_incident_medical_meds` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `med_code` VARCHAR(64) NULL,
    `med_label` VARCHAR(128) NOT NULL,
    `dose` VARCHAR(32) NULL,
    `route` VARCHAR(32) NOT NULL DEFAULT 'iv',
    `patient_citizenid` VARCHAR(64) NULL,
    `patient_name` VARCHAR(128) NULL,
    `medic_citizenid` VARCHAR(64) NULL,
    `medic_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_patient` (`patient_citizenid`),
    CONSTRAINT `fk_medical_meds_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Medical procedures / actions on scene.
CREATE TABLE IF NOT EXISTS `mdt_incident_medical_actions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `action_type` VARCHAR(32) NOT NULL,
    `action_label` VARCHAR(128) NULL,
    `patient_citizenid` VARCHAR(64) NULL,
    `patient_name` VARCHAR(128) NULL,
    `medic_citizenid` VARCHAR(64) NULL,
    `medic_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_action_type` (`action_type`),
    CONSTRAINT `fk_medical_actions_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Equipment used on scene.
CREATE TABLE IF NOT EXISTS `mdt_incident_medical_equipment` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `equipment_type` VARCHAR(32) NOT NULL,
    `item_name` VARCHAR(64) NULL,
    `quantity` INT NOT NULL DEFAULT 1,
    `medic_citizenid` VARCHAR(64) NULL,
    `medic_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_equipment_type` (`equipment_type`),
    CONSTRAINT `fk_medical_equipment_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Phase 3 -------------------------------------------------------------------

-- Responding units. Service-agnostic on purpose: EMS (Phase 4) and mechanics
-- (Phase 5) list their crews here too, `service` tells them apart.
CREATE TABLE IF NOT EXISTS `mdt_incident_officers` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `display_name` VARCHAR(128) NULL,
    `callsign` VARCHAR(16) NULL,
    `badge` VARCHAR(16) NULL,
    `service` VARCHAR(32) NOT NULL DEFAULT 'police',
    `role` VARCHAR(32) NOT NULL DEFAULT 'assist',
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_incident_officer` (`incident_id`, `citizenid`),
    KEY `idx_citizenid` (`citizenid`),
    CONSTRAINT `fk_officers_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Police case extension: one row per police incident.
CREATE TABLE IF NOT EXISTS `mdt_incident_police` (
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `offence_code` VARCHAR(64) NULL,
    `offence_label` VARCHAR(255) NULL,
    `disposition` VARCHAR(32) NOT NULL DEFAULT 'pending',
    `lead_officer_citizenid` VARCHAR(64) NULL,
    `lead_callsign` VARCHAR(16) NULL,
    `station` VARCHAR(64) NULL,
    `arrest_made` TINYINT(1) NOT NULL DEFAULT 0,
    `force_used` TINYINT(1) NOT NULL DEFAULT 0,
    `weapon_involved` TINYINT(1) NOT NULL DEFAULT 0,
    `fine_total` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`incident_id`),
    KEY `idx_disposition` (`disposition`),
    KEY `idx_lead_officer` (`lead_officer_citizenid`),
    CONSTRAINT `fk_police_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Written report: free text + structured meta. One row per (incident, kind) so
-- Phase 4 can store a medical chart next to the police report.
CREATE TABLE IF NOT EXISTS `mdt_incident_reports` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `kind` VARCHAR(32) NOT NULL DEFAULT 'police',
    `title` VARCHAR(255) NULL,
    `body` MEDIUMTEXT NULL,
    `meta` JSON NULL,
    `author_citizenid` VARCHAR(64) NULL,
    `author_name` VARCHAR(128) NULL,
    `updated_by_citizenid` VARCHAR(64) NULL,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_incident_kind` (`incident_id`, `kind`),
    CONSTRAINT `fk_reports_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Use of force. Append-only from gameplay (a correction is a new row + note).
CREATE TABLE IF NOT EXISTS `mdt_incident_force` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `subject_citizenid` VARCHAR(64) NULL,
    `subject_name` VARCHAR(128) NULL,
    `force_type` VARCHAR(32) NOT NULL,
    `tool` VARCHAR(64) NULL,
    `injuries` VARCHAR(32) NOT NULL DEFAULT 'none',
    `medical_called` TINYINT(1) NOT NULL DEFAULT 0,
    `officer_citizenid` VARCHAR(64) NULL,
    `officer_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_force_type` (`force_type`),
    KEY `idx_subject` (`subject_citizenid`),
    CONSTRAINT `fk_force_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Equipment used on scene (spikes, ram, K9, radar…).
CREATE TABLE IF NOT EXISTS `mdt_incident_tools` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `tool_type` VARCHAR(32) NOT NULL,
    `item_name` VARCHAR(64) NULL,
    `quantity` INT NOT NULL DEFAULT 1,
    `officer_citizenid` VARCHAR(64) NULL,
    `officer_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_tool_type` (`tool_type`),
    CONSTRAINT `fk_tools_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seized property. `storage_ref` / `evidence_ref` stay free-form until the
-- evidence locker owns them (Phase 6).
CREATE TABLE IF NOT EXISTS `mdt_incident_seized` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `from_citizenid` VARCHAR(64) NULL,
    `from_name` VARCHAR(128) NULL,
    `item_name` VARCHAR(64) NOT NULL,
    `item_label` VARCHAR(128) NULL,
    `quantity` INT NOT NULL DEFAULT 1,
    `category` VARCHAR(32) NOT NULL DEFAULT 'other',
    `storage_ref` VARCHAR(64) NULL,
    `evidence_ref` VARCHAR(64) NULL,
    `officer_citizenid` VARCHAR(64) NULL,
    `officer_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_category` (`category`),
    KEY `idx_from` (`from_citizenid`),
    CONSTRAINT `fk_seized_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Typed pointers to rows owned by other resources: fines, arrests, fingerprints,
-- bodycam / CCTV / photo / evidence handles. One row per reference, never a blob.
CREATE TABLE IF NOT EXISTS `mdt_incident_refs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `ref_type` VARCHAR(32) NOT NULL,
    `ref_table` VARCHAR(64) NULL,
    `ref_id` VARCHAR(64) NULL,
    `citizenid` VARCHAR(64) NULL,
    `label` VARCHAR(255) NULL,
    `amount` INT NULL,
    `meta` JSON NULL,
    `created_by` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_incident_ref` (`incident_id`, `ref_type`, `ref_id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_ref_type` (`ref_type`),
    KEY `idx_citizenid` (`citizenid`),
    CONSTRAINT `fk_refs_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Phase 6 -------------------------------------------------------------------

-- Evidence locker: chain-of-custody rows linked to police incidents.
CREATE TABLE IF NOT EXISTS `mdt_evidence_items` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `item_name` VARCHAR(64) NOT NULL,
    `item_label` VARCHAR(128) NULL,
    `quantity` INT NOT NULL DEFAULT 1,
    `description` VARCHAR(512) NULL,
    `location` VARCHAR(64) NOT NULL DEFAULT 'mrpd_main',
    `locker_slot` VARCHAR(32) NULL,
    `category` VARCHAR(32) NOT NULL DEFAULT 'other',
    `logged_by_citizenid` VARCHAR(64) NULL,
    `logged_by_name` VARCHAR(128) NULL,
    `sealed` TINYINT(1) NOT NULL DEFAULT 0,
    `sealed_by_citizenid` VARCHAR(64) NULL,
    `sealed_by_name` VARCHAR(128) NULL,
    `sealed_at` TIMESTAMP NULL DEFAULT NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_sealed` (`sealed`),
    KEY `idx_location` (`location`),
    KEY `idx_category` (`category`),
    CONSTRAINT `fk_evidence_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Phase 5 -------------------------------------------------------------------

-- Mechanic repair case extension: one row per mechanic incident.
CREATE TABLE IF NOT EXISTS `mdt_incident_mechanic` (
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `fault_code` VARCHAR(64) NULL,
    `fault_label` VARCHAR(255) NULL,
    `disposition` VARCHAR(32) NOT NULL DEFAULT 'pending',
    `lead_mechanic_citizenid` VARCHAR(64) NULL,
    `lead_callsign` VARCHAR(16) NULL,
    `shop` VARCHAR(64) NULL,
    `tow_requested` TINYINT(1) NOT NULL DEFAULT 0,
    `tow_completed` TINYINT(1) NOT NULL DEFAULT 0,
    `duration_minutes` INT NULL,
    `invoice_total` INT NOT NULL DEFAULT 0,
    `diagnostics_summary` VARCHAR(512) NULL,
    `recommendations` VARCHAR(1024) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`incident_id`),
    KEY `idx_disposition` (`disposition`),
    KEY `idx_lead_mechanic` (`lead_mechanic_citizenid`),
    CONSTRAINT `fk_mechanic_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Diagnostic checks performed on scene.
CREATE TABLE IF NOT EXISTS `mdt_incident_mechanic_diagnostics` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `diag_code` VARCHAR(64) NULL,
    `diag_label` VARCHAR(128) NULL,
    `diag_type` VARCHAR(32) NOT NULL,
    `result` VARCHAR(16) NOT NULL DEFAULT 'unknown',
    `mechanic_citizenid` VARCHAR(64) NULL,
    `mechanic_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_diag_type` (`diag_type`),
    CONSTRAINT `fk_mechanic_diagnostics_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Repair work performed on scene.
CREATE TABLE IF NOT EXISTS `mdt_incident_mechanic_work` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `work_type` VARCHAR(32) NOT NULL,
    `work_label` VARCHAR(128) NULL,
    `duration_minutes` INT NULL,
    `mechanic_citizenid` VARCHAR(64) NULL,
    `mechanic_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_work_type` (`work_type`),
    CONSTRAINT `fk_mechanic_work_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Parts replaced during repair.
CREATE TABLE IF NOT EXISTS `mdt_incident_mechanic_parts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` BIGINT UNSIGNED NOT NULL,
    `part_code` VARCHAR(64) NULL,
    `part_label` VARCHAR(128) NOT NULL,
    `part_category` VARCHAR(32) NOT NULL DEFAULT 'other',
    `quantity` INT NOT NULL DEFAULT 1,
    `mechanic_citizenid` VARCHAR(64) NULL,
    `mechanic_name` VARCHAR(128) NULL,
    `notes` VARCHAR(512) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_incident_id` (`incident_id`),
    KEY `idx_part_category` (`part_category`),
    CONSTRAINT `fk_mechanic_parts_incident`
        FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Phase 7: batched MDT telemetry (analytics.lua flushes on interval).
CREATE TABLE IF NOT EXISTS `mdt_telemetry_events` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `event_type` VARCHAR(64) NOT NULL,
    `service` VARCHAR(32) NULL,
    `actor_citizenid` VARCHAR(64) NULL,
    `value_num` INT NULL,
    `meta` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_event_type` (`event_type`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_service_event` (`service`, `event_type`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Phase 7: incident list hot path (service + status + recency). Safe to re-run.
-- ALTER TABLE `mdt_incidents` ADD KEY `idx_service_status_created` (`service_job`, `status`, `created_at`);

-- Phase 7: PD person search (qb-core `players` — apply manually if LIKE on charinfo is slow):
-- Full-text on charinfo is not recommended (JSON); prefer citizenid exact/prefix + in-memory filter.

-- Phase 7: ltpd domain (composite helps ORDER BY id DESC):
-- ALTER TABLE `ltpd_fines` ADD KEY `idx_citizenid_id` (`citizenid`, `id`);
-- ALTER TABLE `player_vehicles` ADD KEY `idx_citizenid_id` (`citizenid`, `id`);
