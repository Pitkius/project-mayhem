Config = Config or {}

--- Teksto šablonas visiems GTA plokštelės tipams (1=skaitmuo, A=raidė, tarpas=tarpas).
--- Rezultatas pvz.: 482 KTM
Config.PlatePattern = '111 AAA'

--- Kuris plateIndex naudojamas naujoms mašinoms (0 = plate01).
Config.DefaultPlateIndex = 0

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

--- Pakeisti tik pagrindinę baltą plokštelę (plate01). Kitos lieka vanilla.
Config.ReplacePlate01Only = true

--- Serverio numerių generavimas (atitinka PlatePattern: 3 skaitmenys + tarpas + 3 raidės).
Config.ExcludedLetters = { 'I', 'O', 'Q' }
