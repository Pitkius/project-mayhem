CREATE TABLE IF NOT EXISTS `bank_transactions` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `tx_type` VARCHAR(32) NOT NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `balance_after` INT NOT NULL DEFAULT 0,
  `target_citizenid` VARCHAR(50) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_bank_tx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
