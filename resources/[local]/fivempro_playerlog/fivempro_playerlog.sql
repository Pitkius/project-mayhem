-- Žaidėjų veiksmų žurnalas (QBCore + qb-log įvykiai ir papildomi hook'ai).
-- Importuok vieną kartą arba leisk resursui sukurti lentelę automatiškai (server/main.lua).

CREATE TABLE IF NOT EXISTS `fivempro_player_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `display_name` varchar(128) DEFAULT NULL COMMENT 'FiveM rodomas vardas (dažnai sutampa su Steam)',
  `steam_hex` varchar(72) DEFAULT NULL COMMENT 'steam:110000... arba NULL jei nėra Steam',
  `license` varchar(72) DEFAULT NULL,
  `discord` varchar(72) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `char_firstname` varchar(64) DEFAULT NULL,
  `char_lastname` varchar(64) DEFAULT NULL,
  `server_id` int(11) DEFAULT NULL COMMENT 'Serverio slot id logavimo metu',
  `category` varchar(64) NOT NULL,
  `action` varchar(128) NOT NULL,
  `color` varchar(32) DEFAULT NULL,
  `message` mediumtext,
  `meta` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'JSON papildomi laukai',
  `invoking_resource` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_created` (`created_at`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_steam` (`steam_hex`),
  KEY `idx_license` (`license`),
  KEY `idx_category_action` (`category`, `action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
