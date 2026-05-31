CREATE TABLE IF NOT EXISTS `fivempro_trucker_profiles` (
    `citizenid` varchar(50) NOT NULL,
    `registered` tinyint(1) NOT NULL DEFAULT 0,
    `level` int NOT NULL DEFAULT 1,
    `xp` int NOT NULL DEFAULT 0,
    `reputation` int NOT NULL DEFAULT 0,
    `total_deliveries` int NOT NULL DEFAULT 0,
    `total_earned` bigint NOT NULL DEFAULT 0,
    `licenses` longtext DEFAULT NULL,
    `company_id` int DEFAULT NULL,
    `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fivempro_trucker_companies` (
    `id` int NOT NULL AUTO_INCREMENT,
    `owner_citizenid` varchar(50) NOT NULL,
    `name` varchar(64) NOT NULL,
    `logo` varchar(32) DEFAULT 'default',
    `balance` bigint NOT NULL DEFAULT 0,
    `reputation` int NOT NULL DEFAULT 0,
    `total_deliveries` int NOT NULL DEFAULT 0,
    `total_revenue` bigint NOT NULL DEFAULT 0,
    `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_company_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fivempro_trucker_company_members` (
    `company_id` int NOT NULL,
    `citizenid` varchar(50) NOT NULL,
    `role` varchar(16) NOT NULL DEFAULT 'driver',
    `salary` int NOT NULL DEFAULT 0,
    `joined_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`company_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fivempro_trucker_fleet` (
    `id` int NOT NULL AUTO_INCREMENT,
    `company_id` int NOT NULL,
    `model` varchar(32) NOT NULL,
    `label` varchar(64) NOT NULL,
    `plate` varchar(12) NOT NULL,
    `condition_pct` int NOT NULL DEFAULT 100,
    `fuel_pct` int NOT NULL DEFAULT 100,
    `status` varchar(16) NOT NULL DEFAULT 'garage',
    PRIMARY KEY (`id`),
    KEY `idx_fleet_company` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fivempro_trucker_delivery_log` (
    `id` int NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `company_id` int DEFAULT NULL,
    `cargo_type` varchar(32) NOT NULL,
    `pickup_hub` varchar(32) NOT NULL,
    `delivery_hub` varchar(32) NOT NULL,
    `pay` int NOT NULL DEFAULT 0,
    `condition_pct` int NOT NULL DEFAULT 100,
    `on_time` tinyint(1) NOT NULL DEFAULT 1,
    `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_delivery_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
