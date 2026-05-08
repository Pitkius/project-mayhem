CREATE TABLE IF NOT EXISTS `fivempro_dispatch_logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `service` VARCHAR(32) NOT NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `actor_source` INT NULL,
  `actor_citizenid` VARCHAR(64) NULL,
  `payload` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_service` (`service`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

