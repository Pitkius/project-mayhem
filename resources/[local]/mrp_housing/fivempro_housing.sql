CREATE TABLE IF NOT EXISTS `fivempro_property_ownership` (
    `property_id` VARCHAR(64) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `interior_key` VARCHAR(32) NOT NULL,
    `price_paid` INT NOT NULL DEFAULT 0,
    `locked` TINYINT(1) NOT NULL DEFAULT 1,
    `furnished` TINYINT(1) NOT NULL DEFAULT 0,
    `purchased_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`property_id`),
    KEY `idx_fpmho_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fivempro_property_keys` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `property_id` VARCHAR(64) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `granted_by` VARCHAR(50) DEFAULT NULL,
    `granted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_fpmhk_property_citizen` (`property_id`, `citizenid`),
    KEY `idx_fpmhk_citizenid` (`citizenid`),
    KEY `idx_fpmhk_property` (`property_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Jei lentelė jau egzistuoja be furnished:
-- ALTER TABLE fivempro_property_ownership ADD COLUMN furnished TINYINT(1) NOT NULL DEFAULT 0;
