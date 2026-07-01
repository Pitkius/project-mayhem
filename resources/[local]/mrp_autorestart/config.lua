Config = {}

--- Restarto valandos (kas 4 h): 00:00, 04:00, 08:00, 12:00, 16:00, 20:00
Config.RestartHours = { 0, 4, 8, 12, 16, 20 }

--- Minutė restarto metu (0 = tiksliai valandos pradžioje)
Config.RestartAtMinute = 0

--- Perspėjimai likus N minučių (30, 15, 10, 5, 1 min. prieš restartą)
Config.WarningMinutes = { 30, 15, 10, 5, 1 }

--- Kaip dažnai tikrinti laiką (ms)
Config.CheckIntervalMs = 15000

--- Kick žinutė žaidėjams
Config.KickMessage = 'Planinis serverio restartas. Prisijunk po 1–2 minučių.'

--- Po kick — quit (txAdmin / monitorius paleidžia serverį iš naujo)
Config.QuitDelayMs = 4000
Config.QuitReason = 'MRP planinis restartas (kas 4 val.)'

Config.Messages = {
    warning = '⚠ Serverio restartas po %s min.',
    imminent = '⚠ Serveris restartuojamas. Atsijungiama…',
}
