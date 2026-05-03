-- Jei seniau naudojai job pavadinimus fivempro_mechanic / fivempro_ambulance, atnaujink duomenų bazę.
-- QBCore dažniausiai laiko job JSON – pritaikyk pagal savo stulpelį (pavyzdžiai).

-- Jei stulpelis `job` yra JSON (MySQL 5.7+ / MariaDB 10.2+):
-- UPDATE players SET job = JSON_SET(job, '$.name', 'mechanic') WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = 'fivempro_mechanic';
-- UPDATE players SET job = JSON_SET(job, '$.name', 'ambulance') WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = 'fivempro_ambulance';

-- Jei turi atskirą lentelę / kita schema – pakeisk ranka arba per admin setjob: mechanic, ambulance
