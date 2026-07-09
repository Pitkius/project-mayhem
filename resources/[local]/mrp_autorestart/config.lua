Config = {}

--- Restarto valandos (vietinis planinis laikas): 00:00, 04:00, 08:00, 12:00, 16:00, 20:00
Config.RestartHours = { 0, 4, 8, 12, 16, 20 }

--- Minutė restarto metu (0 = tiksliai valandos pradžioje)
Config.RestartAtMinute = 0

--- Jei VPS laikrodis UTC, o nori LT laiko — 3 (vasara) arba 2 (žiema). 0 = serverio OS laikas.
Config.TimezoneOffsetHours = 3

--- Perspėjimai likus N minučių (30, 15, 10, 5, 1 min. prieš restartą)
Config.WarningMinutes = { 30, 15, 10, 5, 1 }

--- Kaip dažnai tikrinti laiką (ms)
Config.CheckIntervalMs = 15000

--- Kiek sekundžių iki planinio laiko pradėti restartą (turi būti mažiau nei CheckIntervalMs)
Config.RestartTriggerSeconds = 8

--- Jei quit nepavyko — atblokuoti ir bandyti vėl (ms)
Config.RestartLockResetMs = 60000

--- Kick žinutė žaidėjams
Config.KickMessage = 'Planinis serverio restartas. Prisijunk po 1–2 minučių.'

--- Po kick — quit (txAdmin Auto Start turi būti įjungtas)
Config.QuitDelayMs = 4000
Config.QuitReason = 'Mayhem Roleplay planinis restartas (kas 4 val.)'

Config.Messages = {
    warning = '⚠ Serverio restartas po %s min.',
    imminent = '⚠ Serveris restartuojamas. Atsijungiama…',
}
