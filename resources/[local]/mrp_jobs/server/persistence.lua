--[[
  mrp_jobs — DB schema + ilgalaikis saugojimas.
  Lentelės kuriamos automatiškai starte (projekto konvencija).
  DB naudojama TIK cooldownams ir statistikai — aktyvi darbo būsena laikoma
  serverio atmintyje (JobManager).
]]

Persistence = Persistence or {}

CreateThread(function()
    -- Cooldownai (pvz. valytojo 2 val. po pilno maršruto).
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_job_cooldowns` (
            `owner_id`   VARCHAR(64)  NOT NULL,   -- citizenid arba license (pagal Config.AccountWideCooldowns)
            `cd_key`     VARCHAR(64)  NOT NULL,
            `expires_at` BIGINT       NOT NULL,   -- os.time() reikšmė
            PRIMARY KEY (`owner_id`, `cd_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Neprivaloma darbų statistika / auditas (lengvas, be didelio srauto).
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_job_stats` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid`  VARCHAR(64)  NOT NULL,
            `job_type`   VARCHAR(32)  NOT NULL,
            `role`       VARCHAR(32)  DEFAULT NULL,
            `category`   VARCHAR(32)  NOT NULL,
            `amount`     INT          NOT NULL DEFAULT 0,
            `meta`       LONGTEXT     DEFAULT NULL,
            `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_cid` (`citizenid`),
            INDEX `idx_job` (`job_type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    if Config.Debug then
        print('[mrp_jobs] DB lentelės paruoštos.')
    end
end)

-- Įrašo įvykį į statistiką/auditą (asinchroniškai, be laukimo).
function Persistence.log(citizenid, jobType, role, category, amount, meta)
    if not citizenid then return end
    MySQL.insert('INSERT INTO fivempro_job_stats (citizenid, job_type, role, category, amount, meta) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid, jobType or 'unknown', role, category or 'misc', math.floor(amount or 0),
        meta and json.encode(meta) or nil,
    })
end
