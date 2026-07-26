-- DESTRUCTIVE: this reset removes every legacy and V2 gang record.
-- Run only while the server is stopped, then run schema_v2.sql.
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `mrp_gang_audit_log`;
DROP TABLE IF EXISTS `mrp_gang_admin_settings`;
DROP TABLE IF EXISTS `mrp_gang_supply_quota`;
DROP TABLE IF EXISTS `mrp_gang_war_score_ledger`;
DROP TABLE IF EXISTS `mrp_gang_war_objectives`;
DROP TABLE IF EXISTS `mrp_gang_war_roster`;
DROP TABLE IF EXISTS `mrp_gang_wars`;
DROP TABLE IF EXISTS `mrp_gang_treaties`;
DROP TABLE IF EXISTS `mrp_gang_territory_history`;
DROP TABLE IF EXISTS `mrp_gang_territories`;
DROP TABLE IF EXISTS `mrp_gang_idempotency`;
DROP TABLE IF EXISTS `mrp_gang_reputation_ledger`;
DROP TABLE IF EXISTS `mrp_gang_mission_rewards`;
DROP TABLE IF EXISTS `mrp_gang_mission_participants`;
DROP TABLE IF EXISTS `mrp_gang_mission_runs`;
DROP TABLE IF EXISTS `mrp_gang_mission_locks`;
DROP TABLE IF EXISTS `mrp_gang_member_responsibilities_v2`;
DROP TABLE IF EXISTS `mrp_gang_invites_v2`;
DROP TABLE IF EXISTS `mrp_gang_roles_v2`;
DROP TABLE IF EXISTS `mrp_gang_members_v2`;
DROP TABLE IF EXISTS `mrp_gangs_v2`;

DROP TABLE IF EXISTS `fivempro_gang_activity_logs`;
DROP TABLE IF EXISTS `fivempro_gang_associates`;
DROP TABLE IF EXISTS `fivempro_gang_invites`;
DROP TABLE IF EXISTS `fivempro_gang_member_responsibilities`;
DROP TABLE IF EXISTS `fivempro_gang_ranks`;
DROP TABLE IF EXISTS `fivempro_gang_relations`;
DROP TABLE IF EXISTS `fivempro_gang_sales_logs`;
DROP TABLE IF EXISTS `fivempro_gang_warnings`;
DROP TABLE IF EXISTS `fivempro_gang_members`;
DROP TABLE IF EXISTS `fivempro_gang_turfs`;
DROP TABLE IF EXISTS `fivempro_gangs`;

SET FOREIGN_KEY_CHECKS = 1;

-- Next: execute sql/schema_v2.sql before starting mrp_gangs.
