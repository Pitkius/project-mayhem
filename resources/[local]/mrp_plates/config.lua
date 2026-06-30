Config = Config or {}

--- Teksto šablonas GTA generavimui (1=skaitmuo, A=raidė). Vienas tarpas kairėje — lygiavimas ant tekstūros.
--- Rezultatas pvz.: 482 KTM
Config.PlatePattern = ' 111 AAA'

--- Kiek tarpų prieš skaitmenis ant mašinos (max 1 — GTA limitas 8 simboliai).
Config.PlateTextPadLeft = 1

--- plate index 5 (yankton_plate) — variklis nepiešia „San Andreas“ antraštės (0/1 ją rodo).
Config.DefaultPlateIndex = 5

--- MRP violetinė tematika (atitinka HUD / autosaloną).
Config.Theme = {
    accent = '#a78bfa',
    accentSoft = '#c4b5fd',
    band = '#4c1d95',
    bandDark = '#3b0764',
}

--- Runtime tekstūros vardas (AddReplaceTexture).
Config.TextureDict = 'mrp_plates_txd'
Config.PlateTexture = 'plate01'
Config.PlateTextureFile = 'textures/plate01.png'

--- Logo kairėje zonoje (loadscreen asset).
Config.LogoFile = '../mrp_loadscreen/html/assets/mrp_logo.png'

--- Pakeisti vanilla tekstūras (įsk. yankton — be SA antraštės).
Config.ReplaceVanillaPlates = { 'plate01', 'plate02', 'yankton_plate' }

--- Serverio numerių generavimas (atitinka PlatePattern: 3 skaitmenys + tarpas + 3 raidės).
Config.ExcludedLetters = { 'I', 'O', 'Q' }
