CREATE TABLE IF NOT EXISTS `fivempro_property_ownership` (
    `property_id` VARCHAR(64) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `interior_key` VARCHAR(32) NOT NULL,
    `price_paid` INT NOT NULL DEFAULT 0,
    `locked` TINYINT(1) NOT NULL DEFAULT 1,
    `purchased_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`property_id`),
    KEY `idx_fpmho_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
