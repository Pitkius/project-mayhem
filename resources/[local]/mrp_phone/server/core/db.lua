PhoneDB = PhoneDB or {}

local LEGACY_TABLES = {
    'fivempro_phone_users',
    'fivempro_phone_contacts',
    'fivempro_phone_messages',
    'fivempro_phone_ads',
    'fivempro_phone_notes',
    'fivempro_phone_notes_v2',
    'fivempro_phone_photos',
    'fivempro_phone_ad_profiles',
    'fivempro_phone_posts',
    'fivempro_phone_accounts',
    'fivempro_phone_installed_apps',
    'fivempro_phone_bank_accounts',
    'fivempro_phone_bank_transactions',
}

local function dropLegacy()
    if not (Config.Phone and Config.Phone.WipeLegacyTables) then return end
    for _, name in ipairs(LEGACY_TABLES) do
        MySQL.query.await(('DROP TABLE IF EXISTS `%s`'):format(name))
    end
    print('[mrp_phone] Legacy phone tables wiped (WipeLegacyTables=true).')
end

local function createCore()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phones` (
          `phone_id` varchar(36) NOT NULL,
          `owner_citizenid` varchar(60) DEFAULT NULL,
          `phone_number` varchar(16) NOT NULL,
          `imei` varchar(24) NOT NULL,
          `sim_id` varchar(24) NOT NULL,
          `pin_hash` varchar(255) DEFAULT NULL,
          `phone_type` varchar(16) NOT NULL DEFAULT 'legal',
          `status` varchar(16) NOT NULL DEFAULT 'active',
          `pin_fail_count` int NOT NULL DEFAULT 0,
          `pin_lockout_until` int NOT NULL DEFAULT 0,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`phone_id`),
          UNIQUE KEY `uniq_phone_number` (`phone_number`),
          UNIQUE KEY `uniq_phone_imei` (`imei`),
          UNIQUE KEY `uniq_phone_sim` (`sim_id`),
          KEY `idx_phone_owner` (`owner_citizenid`),
          KEY `idx_phone_type` (`phone_type`),
          KEY `idx_phone_status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_audit` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `actor_citizenid` varchar(60) DEFAULT NULL,
          `action` varchar(48) NOT NULL,
          `detail` varchar(255) DEFAULT NULL,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_audit_phone` (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_contacts` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `name` varchar(64) NOT NULL,
          `number` varchar(16) NOT NULL,
          `service` varchar(24) DEFAULT NULL,
          `icon` varchar(40) DEFAULT NULL,
          `is_default` tinyint(1) NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`),
          KEY `idx_contacts_phone` (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_messages` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `thread_number` varchar(16) NOT NULL,
          `direction` varchar(8) NOT NULL DEFAULT 'in',
          `body` varchar(500) NOT NULL,
          `from_number` varchar(16) DEFAULT NULL,
          `read_flag` tinyint(1) NOT NULL DEFAULT 0,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_msg_phone` (`phone_id`, `created_at`),
          KEY `idx_msg_thread` (`phone_id`, `thread_number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_call_log` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `peer_number` varchar(16) NOT NULL,
          `direction` varchar(8) NOT NULL DEFAULT 'out',
          `status` varchar(16) NOT NULL DEFAULT 'missed',
          `duration_sec` int NOT NULL DEFAULT 0,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_calls_phone` (`phone_id`, `created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_photos` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `file_path` varchar(255) NOT NULL DEFAULT '',
          `image_url` varchar(500) NOT NULL DEFAULT '',
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_photos_phone` (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_notes` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `title` varchar(64) NOT NULL DEFAULT '',
          `body` mediumtext NOT NULL,
          `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_notes_phone` (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_ads` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `title` varchar(64) NOT NULL,
          `body` varchar(320) NOT NULL,
          `category` varchar(32) NOT NULL DEFAULT 'other',
          `price` int DEFAULT NULL,
          `image_url` varchar(500) DEFAULT NULL,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_ads_phone` (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_ad_profiles` (
          `phone_id` varchar(36) NOT NULL,
          `display_name` varchar(64) NOT NULL DEFAULT '',
          `bio` varchar(260) NOT NULL DEFAULT '',
          `avatar_url` varchar(500) DEFAULT NULL,
          PRIMARY KEY (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_posts` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `author_name` varchar(64) NOT NULL,
          `caption` varchar(260) NOT NULL,
          `image_url` varchar(500) NOT NULL DEFAULT '',
          `likes` int NOT NULL DEFAULT 0,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_posts_phone` (`phone_id`),
          KEY `idx_posts_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_installed_apps` (
          `phone_id` varchar(36) NOT NULL,
          `app_id` varchar(40) NOT NULL,
          `installed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`phone_id`, `app_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_bank_accounts` (
          `phone_id` varchar(36) NOT NULL,
          `account_number` varchar(24) NOT NULL,
          `card_last4` varchar(4) NOT NULL,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`phone_id`),
          UNIQUE KEY `uniq_bank_account` (`account_number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_bank_transactions` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `tx_type` varchar(24) NOT NULL DEFAULT 'other',
          `amount` int NOT NULL DEFAULT 0,
          `title` varchar(80) NOT NULL DEFAULT '',
          `counterparty` varchar(64) NULL,
          `counterparty_citizenid` varchar(60) NULL,
          `purpose` varchar(120) NULL,
          `status` varchar(16) NOT NULL DEFAULT 'completed',
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_bank_tx_phone` (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_encrypted_threads` (
          `id` int NOT NULL AUTO_INCREMENT,
          `phone_id` varchar(36) NOT NULL,
          `peer_label` varchar(64) NOT NULL DEFAULT 'Unknown',
          `peer_phone_id` varchar(36) DEFAULT NULL,
          `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_enc_threads_phone` (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_phone_encrypted_messages` (
          `id` int NOT NULL AUTO_INCREMENT,
          `thread_id` int NOT NULL,
          `phone_id` varchar(36) NOT NULL,
          `direction` varchar(8) NOT NULL DEFAULT 'out',
          `body` varchar(500) NOT NULL,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_enc_msg_thread` (`thread_id`, `created_at`),
          KEY `idx_enc_msg_phone` (`phone_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

function PhoneDB.Init()
    dropLegacy()
    createCore()
    print('[mrp_phone] PhoneID schema ready.')
end

function PhoneDB.Audit(phoneId, actorCitizenid, action, detail)
    if not phoneId or not action then return end
    MySQL.insert.await(
        'INSERT INTO mrp_phone_audit (phone_id, actor_citizenid, action, detail) VALUES (?, ?, ?, ?)',
        { phoneId, actorCitizenid, tostring(action), detail and tostring(detail):sub(1, 255) or nil }
    )
end

MySQL.ready(function()
    PhoneDB.Init()
end)
