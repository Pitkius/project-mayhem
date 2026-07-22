-- Revert the automatic mrpd1-12 -> gcpd/gcapd migration.
-- Stop the server before running this rollback.
UPDATE `player_vehicles` AS pv
INNER JOIN `mrp_vehicle_model_migration_backup` AS b
    ON b.`plate` = pv.`plate`
SET
    pv.`vehicle` = b.`old_vehicle`,
    pv.`hash` = b.`old_hash`,
    pv.`mods` = b.`old_mods`
WHERE pv.`vehicle` = b.`new_vehicle`;

-- Keep the backup table until the rollback has been verified.
