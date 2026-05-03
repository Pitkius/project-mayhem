-- fivempro_ltpd – lentelės (kopijuojamos ir iš server/main.lua ensureTables paleidimo metu)
-- Charset: utf8mb4

CREATE TABLE IF NOT EXISTS `ltpd_profiles` (
    `citizenid` varchar(50) NOT NULL,
    `division` varchar(32) NOT NULL DEFAULT 'patrol',
    `badge` varchar(16) DEFAULT NULL,
    `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    PRIMARY KEY (`citizenid`),
    KEY `division` (`division`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ltpd_fines` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `officer_citizenid` varchar(50) NOT NULL,
    `amount` int(11) NOT NULL,
    `reason_code` varchar(64) DEFAULT NULL,
    `reason_label` varchar(255) DEFAULT NULL,
    `created_at` datetime NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `officer` (`officer_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ltpd_wanted` (
    `citizenid` varchar(50) NOT NULL,
    `level` tinyint(4) NOT NULL DEFAULT 0,
    `reason` varchar(512) DEFAULT NULL,
    `updated_by` varchar(50) DEFAULT NULL,
    `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ltpd_wanted_history` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `level` tinyint(4) NOT NULL,
    `officer_citizenid` varchar(50) DEFAULT NULL,
    `note` varchar(512) DEFAULT NULL,
    `created_at` datetime NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ltpd_arrests` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `officer_citizenid` varchar(50) NOT NULL,
    `notes` text,
    `created_at` datetime NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
