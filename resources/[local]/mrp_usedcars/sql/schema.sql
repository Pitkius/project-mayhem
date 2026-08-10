CREATE TABLE IF NOT EXISTS `mrp_usedcar_listings` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `plate` VARCHAR(16) NOT NULL,
  `seller_citizenid` VARCHAR(64) NOT NULL,
  `model` VARCHAR(64) NOT NULL,
  `mods` LONGTEXT NULL,
  `price` INT NOT NULL,
  `listed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `slot_index` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_plate` (`plate`),
  KEY `idx_seller` (`seller_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
