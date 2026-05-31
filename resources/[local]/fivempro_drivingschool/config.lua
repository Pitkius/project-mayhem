Config = {}

Config.Blip = {
    sprite = 498,
    colour = 3,
    scale = 0.85,
    label = 'Vairavimo mokykla',
}

Config.PedModel = 's_m_m_gentransport'
Config.PedScenario = 'WORLD_HUMAN_CLIPBOARD'
Config.TargetDistance = 2.5

--- Pagrindinė vieta (LSIA / oro uosto zona)
Config.Location = {
    coords = vector4(-893.17, -2401.53, 14.02, 330.06),
    vehicleSpawn = vector4(-887.50, -2395.80, 13.85, 330.06),
}

Config.TheoryPassPercent = 80
Config.TheoryQuestionCount = 20
Config.PracticalMaxErrors = 8
Config.PracticalCheckpointRadius = 6.0
Config.SpeedGraceKmh = 5
Config.SpeedViolationSeconds = 3.0

Config.Categories = {
    a = {
        id = 'a',
        label = 'A kategorija — Motociklai',
        icon = '🏍️',
        licenceKey = 'driver_a',
        licenceLabel = 'A kategorijos vairuotojo pažymėjimas',
        examPrice = 750,
        vehicleModel = 'faggio2',
        speedLimitKmh = 50,
        routeSpeedLimits = { 50, 50, 60, 60, 50, 50, 45, 45, 50, 50, 55, 55, 50, 50, 40 },
    },
    b = {
        id = 'b',
        label = 'B kategorija — Lengvieji automobiliai',
        icon = '🚗',
        licenceKey = 'driver',
        licenceKeys = { 'driver', 'driver_b' },
        licenceLabel = 'B kategorijos vairuotojo pažymėjimas',
        examPrice = 500,
        vehicleModel = 'blista',
        speedLimitKmh = 50,
        routeSpeedLimits = { 50, 50, 60, 60, 50, 50, 45, 45, 50, 50, 55, 55, 50, 50, 40 },
    },
    c = {
        id = 'c',
        label = 'C kategorija — Sunkvežimiai / Furos',
        icon = '🚛',
        licenceKey = 'driver_c',
        licenceLabel = 'C kategorijos vairuotojo pažymėjimas',
        examPrice = 1200,
        vehicleModel = 'mule',
        speedLimitKmh = 40,
        routeSpeedLimits = { 40, 40, 45, 45, 40, 40, 35, 35, 40, 40, 45, 45, 40, 40, 30 },
    },
}

--- 15 kontrolinių taškų maršrutas (pradžia = pabaiga)
Config.RouteCheckpoints = {
    vector3(-893.17, -2401.53, 14.02),
    vector3(-928.40, -2375.20, 14.02),
    vector3(-978.60, -2358.40, 14.02),
    vector3(-1038.20, -2388.50, 14.02),
    vector3(-1095.80, -2438.60, 14.02),
    vector3(-1128.40, -2498.30, 14.02),
    vector3(-1098.20, -2558.70, 14.02),
    vector3(-1042.50, -2598.40, 14.02),
    vector3(-972.30, -2618.80, 14.02),
    vector3(-902.60, -2592.40, 14.02),
    vector3(-842.80, -2542.30, 14.02),
    vector3(-798.40, -2482.60, 14.02),
    vector3(-812.60, -2418.90, 14.02),
    vector3(-858.90, -2368.40, 14.02),
    vector3(-893.17, -2401.53, 14.02),
}

--- Visi klausimai (20 kiekvienai kategorijai)
Config.Questions = {
    a = {
        { q = 'Ką privaloma dėvėti važiuojant motociklu?', answers = { 'Kepurę', 'Šalmą', 'Akinius', 'Pirštines' }, correct = 2 },
        { q = 'Kokia yra pagrindinė motociklininko rizika?', answers = { 'Didelė kuro sąnauda', 'Mažesnė apsauga avarijos metu', 'Triukšmas', 'Lėtas greitis' }, correct = 2 },
        { q = 'Kada galima lenkti?', answers = { 'Kai saugu ir leidžia ženklinimas', 'Visada', 'Tik mieste', 'Tik užmiestyje' }, correct = 1 },
        { q = 'Kur motociklininkas turi važiuoti?', answers = { 'Šaligatviu', 'Kelkraščiu', 'Eismo juosta', 'Tarp automobilių visada' }, correct = 3 },
        { q = 'Ką daryti lyjant?', answers = { 'Didinti greitį', 'Važiuoti atsargiau', 'Stabdyti tik galiniu stabdžiu', 'Išjungti šviesas' }, correct = 2 },
        { q = 'Kada naudoti posūkio signalą?', answers = { 'Tik mieste', 'Tik sankryžoje', 'Prieš manevrą', 'Nereikia' }, correct = 3 },
        { q = 'Kodėl svarbu laikytis atstumo?', answers = { 'Dėl kuro taupymo', 'Kad spėtum sustabdyti', 'Dėl triukšmo', 'Dėl komforto' }, correct = 2 },
        { q = 'Ką reiškia geltonas šviesoforo signalas?', answers = { 'Greitinti', 'Sustoti jei saugu', 'Ignoruoti', 'Važiuoti greičiau' }, correct = 2 },
        { q = 'Kurio stabdžio nereikėtų naudoti staigiai slidžiame kelyje?', answers = { 'Priekinio', 'Galinio', 'Abiejų', 'Sankabos' }, correct = 1 },
        { q = 'Kas yra akloji zona?', answers = { 'Vieta kur tavęs gali nematyti kiti vairuotojai', 'Šaligatvis', 'Stovėjimo aikštelė', 'Autobusų stotelė' }, correct = 1 },
        { q = 'Kada įjungti artimąsias šviesas?', answers = { 'Tik tunelyje', 'Kai tamsu arba prastas matomumas', 'Visada dieną', 'Tik greitkelyje' }, correct = 2 },
        { q = 'Ką reiškia STOP ženklas?', answers = { 'Sulėtinti', 'Visiškai sustoti', 'Važiuoti atsargiai', 'Ignoruoti' }, correct = 2 },
        { q = 'Kaip elgtis prie pėsčiųjų perėjos?', answers = { 'Signalizuoti ir važiuoti', 'Sustoti ir praleisti pėsčiuosius', 'Greitinti', 'Lenkti' }, correct = 2 },
        { q = 'Ką daryti sugedus motociklui?', answers = { 'Palikti kelyje', 'Važiuoti toliau lėtai', 'Pastatyti saugioje vietoje ir įjungti avarinius', 'Stabdyti viduryje juostos' }, correct = 3 },
        { q = 'Ar galima važiuoti be rankų?', answers = { 'Taip, trumpai', 'Ne, draudžiama', 'Tik mieste', 'Tik stovint' }, correct = 2 },
        { q = 'Kada tikrinti padangų slėgį?', answers = { 'Kartą per metus', 'Tik po avarijos', 'Reguliariai, bent kartą per mėnesį', 'Niekada' }, correct = 3 },
        { q = 'Ką reiškia ištisinė linija?', answers = { 'Galima lenkti', 'Draudžiama kirsti', 'Galima apsisukti', 'Parkavimo vieta' }, correct = 2 },
        { q = 'Kaip veikia ABS?', answers = { 'Neleidžia užblokuoti ratų stabdant', 'Padidina greitį', 'Išjungia stabdžius', 'Taupo kurą' }, correct = 1 },
        { q = 'Kas svarbiausia prieš ilgą kelionę?', answers = { 'Pasiklausyti muzikos', 'Patikrinti transporto priemonės būklę', 'Pakeisti spalvą', 'Nuplauti salonus' }, correct = 2 },
        { q = 'Kaip stabdymo kelias keičiasi lyjant?', answers = { 'Sutrumpėja', 'Nesikeičia', 'Pailgėja', 'Išnyksta' }, correct = 3 },
    },
    b = {
        { q = 'Ką privalo segėti vairuotojas?', answers = { 'Šalmą', 'Saugos diržą', 'Liemenę', 'Pirštines' }, correct = 2 },
        { q = 'Ką reiškia STOP ženklas?', answers = { 'Sulėtinti', 'Visiškai sustoti', 'Važiuoti atsargiai', 'Ignoruoti' }, correct = 2 },
        { q = 'Kada naudoti posūkio signalą?', answers = { 'Prieš manevrą', 'Po manevro', 'Tik mieste', 'Nereikia' }, correct = 1 },
        { q = 'Kas turi pirmenybę pėsčiųjų perėjoje?', answers = { 'Automobilis', 'Pėsčiasis', 'Dviratis', 'Motociklas' }, correct = 2 },
        { q = 'Ką reiškia raudonas šviesoforas?', answers = { 'Sulėtinti', 'Sustoti', 'Greitinti', 'Persirikiuoti' }, correct = 2 },
        { q = 'Kada galima naudoti telefoną?', answers = { 'Visada', 'Tik stovint arba laisvų rankų įranga', 'Važiuojant', 'Sankryžoje' }, correct = 2 },
        { q = 'Kas yra akloji zona?', answers = { 'Zona kurios nesimato veidrodžiuose', 'Parkavimo vieta', 'Šaligatvis', 'Aikštelė' }, correct = 1 },
        { q = 'Kodėl svarbu laikytis saugaus atstumo?', answers = { 'Taupyti kurą', 'Sumažinti susidūrimo riziką', 'Važiuoti greičiau', 'Dėl komforto' }, correct = 2 },
        { q = 'Ką reiškia ištisinė linija?', answers = { 'Galima lenkti', 'Draudžiama kirsti', 'Galima apsisukti', 'Parkavimo vieta' }, correct = 2 },
        { q = 'Kada naudoti avarinius žibintus?', answers = { 'Sugedus automobiliui', 'Visada', 'Lyjant', 'Mieste' }, correct = 1 },
        { q = 'Kada naudoti tolimąsias šviesas?', answers = { 'Mieste visada', 'Tik stovint', 'Užmiestyje, kai nėra priešingų', 'Tunelyje dieną' }, correct = 3 },
        { q = 'Kaip elgtis žiede?', answers = { 'Greitinti įvažiuojant', 'Pirmenybė tiems, kas jau žiede', 'Stabdyti žiede', 'Važiuoti dešine juosta' }, correct = 2 },
        { q = 'Kada reikia praleisti autobusą?', answers = { 'Kai jis važiuoja', 'Kai autobusas stovi stotelėje ir įjungta posūkio lemputė', 'Niekada', 'Tik greitkelyje' }, correct = 2 },
        { q = 'Ką daryti eismo įvykio metu?', answers = { 'Pasišalinti', 'Sustoti, įvertinti, informuoti', 'Važiuoti toliau', 'Ignoruoti' }, correct = 2 },
        { q = 'Kada tikrinti alyvą?', answers = { 'Kartą per metus', 'Reguliariai pagal gamintojo rekomendacijas', 'Niekada', 'Tik po remonto' }, correct = 2 },
        { q = 'Ką reiškia mėlynas ženklas?', answers = { 'Draudimas', 'Informacija arba nurodymas', 'Pavojus', 'Greičio ribojimas' }, correct = 2 },
        { q = 'Kaip veikia ABS?', answers = { 'Neleidžia ratams užsiblokuoti', 'Padidina greitį', 'Išjungia stabdžius', 'Sumažina degalų sąnaudas' }, correct = 1 },
        { q = 'Ką daryti prasidėjus slydimui?', answers = { 'Stabdyti staigiai', 'Atleisti akseleratorių ir vairuoti kryptimi', 'Greitinti', 'Išjungti variklį' }, correct = 2 },
        { q = 'Kiek svarbios padangos?', answers = { 'Nesvarbios', 'Svarbios tik žiemą', 'Labai svarbios saugumui', 'Tik estetikai' }, correct = 3 },
        { q = 'Kas turi pirmenybę nereguliuojamoje sankryžoje (dešinės rankos taisyklė)?', answers = { 'Kairėje esantis', 'Dešinėje esantis', 'Greitesnis', 'Didesnis automobilis' }, correct = 2 },
    },
    c = {
        { q = 'Kas labiausiai skiriasi vairuojant furą?', answers = { 'Didesnis stabdymo kelias', 'Didesnis radijas', 'Mažesnis svoris', 'Greitesnis įsibėgėjimas' }, correct = 1 },
        { q = 'Kodėl svarbu palikti didelį atstumą?', answers = { 'Dėl kuro', 'Dėl ilgesnio stabdymo kelio', 'Dėl radijo ryšio', 'Dėl komforto' }, correct = 2 },
        { q = 'Kas yra akloji zona sunkvežimyje?', answers = { 'Zona kurios vairuotojas nemato veidrodžiais', 'Kabina', 'Priekaba', 'Kelkraštis' }, correct = 1 },
        { q = 'Ką reikia patikrinti prieš reisą?', answers = { 'Tik kurą', 'Tik padangas', 'Transporto priemonės būklę', 'Tik šviesas' }, correct = 3 },
        { q = 'Kodėl sunkvežimiai sunkiau manevruoja?', answers = { 'Dėl dydžio ir svorio', 'Dėl kuro', 'Dėl oro', 'Dėl radijo' }, correct = 1 },
        { q = 'Ką daryti leidžiantis nuo kalno?', answers = { 'Įjungti neutralią pavarą', 'Naudoti variklinį stabdymą', 'Greitėti', 'Išjungti variklį' }, correct = 2 },
        { q = 'Kas pavojingiausia posūkyje?', answers = { 'Didelis greitis', 'Muzika', 'Šviesos', 'Oro temperatūra' }, correct = 1 },
        { q = 'Kada tikrinti krovinį?', answers = { 'Tik išvykstant', 'Reguliariai kelionės metu', 'Niekada', 'Tik atvykus' }, correct = 2 },
        { q = 'Ką reiškia viršytas svoris?', answers = { 'Nieko', 'Pavojus ir baudos', 'Greitesnis važiavimas', 'Mažesnės kuro sąnaudos' }, correct = 2 },
        { q = 'Kodėl svarbu tvirtinti krovinį?', answers = { 'Kad nejudėtų važiuojant', 'Dėl išvaizdos', 'Dėl kuro', 'Dėl komforto' }, correct = 1 },
        { q = 'Kada naudoti retarderį?', answers = { 'Leidžiantis nuo kalno arba stabdant', 'Kylant', 'Stovint', 'Parkuojantis' }, correct = 1 },
        { q = 'Ką daryti sprogus padangai?', answers = { 'Stabdyti staigiai', 'Laikyti vairą ir lėtai stabdyti', 'Greitinti', 'Išlipti važiuojant' }, correct = 2 },
        { q = 'Kaip lenkti su priekaba?', answers = { 'Greitai ir staigiai', 'Tik kai saugu, plačiai ir lėtai', 'Visada', 'Niekada' }, correct = 2 },
        { q = 'Ką reiškia svorio apribojimo ženklas?', answers = { 'Rekomenduojamas svoris', 'Maksimalus leistinas svoris', 'Minimalus svoris', 'Nesvarbu' }, correct = 2 },
        { q = 'Kada tikrinti stabdžius?', answers = { 'Niekada', 'Prieš kiekvieną reisą', 'Kartą per metus', 'Tik po avarijos' }, correct = 2 },
        { q = 'Kaip važiuoti per siaurą tiltą?', answers = { 'Greitai', 'Lėtai ir centre, atsižvelgiant į plotį', 'Kairėje', 'Dešinėje kraštine' }, correct = 2 },
        { q = 'Kas yra puspriekabė?', answers = { 'Lengvas automobilis', 'Priekaba su dalimi svorio ant vilkiko', 'Dviratis', 'Autobusas' }, correct = 2 },
        { q = 'Kodėl svarbūs veidrodžiai?', answers = { 'Estetikai', 'Matyti akląsias zonas', 'Radijui', 'Kuro taupymui' }, correct = 2 },
        { q = 'Ką daryti slidžiame kelyje?', answers = { 'Greitinti', 'Važiuoti lėčiau ir atsargiau', 'Stabdyti staigiai', 'Išjungti šviesas' }, correct = 2 },
        { q = 'Kodėl sunkvežimis posūkyje gali apvirsti net neviršydamas greičio ribojimo?', answers = { 'Dėl aukščio centro gravitacijos ir svorio', 'Dėl radijo', 'Dėl kuro', 'Dėl oro kondicionieriaus' }, correct = 1 },
    },
}
