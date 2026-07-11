--[[
  mrp_jobs — framework nustatymai (shared).
  Čia tik bendri techniniai parametrai. Kainos → config/rewards.lua,
  vietos → config/locations.lua, darbai → config/jobs.lua.
]]

Config = Config or {}

Config.Debug = false

-- Komanda darbo meniu atidaryti (papildomai prie NPC / target).
Config.OpenCommand = 'darbas'

-- Target atstumai
Config.Target = {
    npcDistance = 2.5,
    zoneDistance = 2.2,
}

-- Notify: naudojam QBCore.Functions.Notify. Čia trukmės.
Config.Notify = {
    duration = 5000,
}

-- Progress bar (naudojam QBCore.Functions.Progressbar su vidiniu fallback).
Config.Progress = {
    -- Jei serveryje įdiegtas 'progressbar' resursas — jis naudojamas automatiškai.
    -- Kitu atveju veikia mrp_jobs vidinis fallback (anim + laikmatis).
}

-- Rate limit (anti-spam) numatytieji minimalūs intervalai (ms) jautriems eventams.
Config.RateLimit = {
    default   = 600,    -- bendras minimalus intervalas tarp to paties veiksmo
    minigame  = 900,    -- minigame rezultato pateikimas
    delivery  = 1200,   -- pristatymo veiksmai
    order     = 500,    -- kasos veiksmai
}

-- Ar cooldownai saugomi DB (persistentiniai per restartą / atsijungimą).
Config.PersistCooldowns = true

-- Ar cooldownai taikomi visai paskyrai (account-wide), ne tik veikėjui.
-- true = rišama prie license identifikatoriaus; false = prie citizenid.
Config.AccountWideCooldowns = false

-- Maksimalus atstumas (m), kuriuo serveris laiko žaidėją "vietoje".
Config.MaxInteractDistance = 4.5
