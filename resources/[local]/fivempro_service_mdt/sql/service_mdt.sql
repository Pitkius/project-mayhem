CREATE TABLE IF NOT EXISTS `fivempro_service_invoices` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `service` VARCHAR(32) NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `issuer_citizenid` VARCHAR(64) NOT NULL,
    `amount` INT NOT NULL,
    `reason_code` VARCHAR(64) NULL,
    `reason_label` VARCHAR(255) NOT NULL,
    `plate` VARCHAR(16) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_service_citizen` (`service`, `citizenid`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
