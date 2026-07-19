-- Run AFTER freeing disk space on the DB host.
-- Fixes missing columns that failed to migrate when Errcode 28 (disk full) hit.
-- Ignore "Duplicate column" errors if a column already exists.

ALTER TABLE `fivempro_gangs` ADD COLUMN `secondary_color_hex` VARCHAR(16) NOT NULL DEFAULT '#FFFFFF' AFTER `color_hex`;
ALTER TABLE `fivempro_gangs` ADD COLUMN `owner_citizenid` VARCHAR(64) NULL AFTER `secondary_color_hex`;
ALTER TABLE `fivempro_gangs` ADD COLUMN `parent_gang_id` INT NULL DEFAULT NULL AFTER `owner_citizenid`;
ALTER TABLE `fivempro_gangs` ADD COLUMN `warnings` INT NOT NULL DEFAULT 0 AFTER `heat`;
ALTER TABLE `fivempro_gang_turfs` ADD COLUMN `influence` INT NOT NULL DEFAULT 0 AFTER `progress`;
ALTER TABLE `ltpd_profiles` ADD COLUMN `craft_level` TINYINT NOT NULL DEFAULT 1;
ALTER TABLE `ltpd_profiles` ADD COLUMN `crafts_at_level` INT NOT NULL DEFAULT 0;
