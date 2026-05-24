CREATE TABLE IF NOT EXISTS `fivempro_gangs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL,
  `gang_type` VARCHAR(32) NOT NULL,
  `color_hex` VARCHAR(16) NOT NULL DEFAULT '#FFFFFF',
  `secondary_color_hex` VARCHAR(16) NOT NULL DEFAULT '#FFFFFF',
  `owner_citizenid` VARCHAR(64) NULL,
  `reputation` INT NOT NULL DEFAULT 0,
  `heat` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_fivempro_gangs_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fivempro_gang_members` (
  `gang_id` INT NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `rank` INT NOT NULL DEFAULT 1,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`gang_id`, `citizenid`),
  KEY `idx_fivempro_gang_members_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fivempro_gang_turfs` (
  `turf_id` VARCHAR(64) NOT NULL,
  `owner_gang_id` INT NULL,
  `owner_name` VARCHAR(64) NULL,
    `progress` INT NOT NULL DEFAULT 0,
    `influence` INT NOT NULL DEFAULT 0,
  `heat` INT NOT NULL DEFAULT 0,
  `sales_count` INT NOT NULL DEFAULT 0,
  `total_profit` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`turf_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `fivempro_gang_sales_logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `turf_id` VARCHAR(64) NOT NULL,
  `item_name` VARCHAR(64) NOT NULL,
  `amount` INT NOT NULL DEFAULT 1,
  `profit` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_fivempro_gang_sales_logs_gang` (`gang_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `fivempro_gang_turfs` (`turf_id`) VALUES
('grove'),
('davis'),
('rancho'),
('chamberlain'),
('strawberry'),
('missionrow'),
('textile'),
('downtown'),
('vinewood'),
('mirrorpark'),
('little_seoul'),
('delperro'),
('cypress'),
('la_puerta'),
('elburro'),
('sandy'),
('grapeseed'),
('paleto');
