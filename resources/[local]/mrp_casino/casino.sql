CREATE TABLE IF NOT EXISTS `casino_player_stats` (
    `citizenid` VARCHAR(50) NOT NULL,
    `day_key` VARCHAR(10) NOT NULL DEFAULT '',
    `daily_wins` INT NOT NULL DEFAULT 0,
    `banned_until` VARCHAR(10) NOT NULL DEFAULT '',
    `wheel_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `casino_state` (
    `id` VARCHAR(32) NOT NULL,
    `data` LONGTEXT NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
