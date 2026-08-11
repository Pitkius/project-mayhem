--[[
  Dashboard crate unlock + mission progress config.

  Mission counter (no dedicated mrp_missions resource):
  - Trucking delivery complete (mrp_trucking)
  - Gang mission complete per eligible participant (mrp_gangs)
  - Civilian job session complete (mrp_jobs reason=complete)
  - Any resource: exports['mrp_dashboard']:RecordMissionComplete(src, sourceTag)
]]

Config = Config or {}

Config.Crates = {
    --- Playtime gates (minutes online in period)
    dailyPlayMinutes = 120,   -- 2h šiandien
    weeklyPlayMinutes = 600,  -- 10h šią savaitę

    --- Completed activity missions required in period
    dailyMissionsRequired = 3,
    weeklyMissionsRequired = 12,
}

--- Money-earn missions on Misijos tab (separate from crate mission-count gate)
Config.Missions = {
    dailyMoney = 3000,
    weeklyMoney = 25000,
    dailyTitle = 'Uždirbk $3,000 šiandien',
    weeklyTitle = 'Uždirbk $25,000 šią savaitę',
}
