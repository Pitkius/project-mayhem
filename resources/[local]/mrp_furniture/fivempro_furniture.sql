CREATE TABLE IF NOT EXISTS `fivempro_furniture` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `property_id` VARCHAR(64) NOT NULL,
    `item_key` VARCHAR(64) NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `rx` FLOAT NOT NULL DEFAULT 0,
    `ry` FLOAT NOT NULL DEFAULT 0,
    `rz` FLOAT NOT NULL DEFAULT 0,
    `meta` LONGTEXT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_fpmf_property` (`property_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
