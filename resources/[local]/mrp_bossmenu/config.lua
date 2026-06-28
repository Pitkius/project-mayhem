Config = {}

--- Frakcijos algos kas X min (QBCore PayCheckTimeOut naudojamas, jei nil)
Config.PaycheckMinutes = nil

Config.Jobs = {
    police = {
        label = 'Lietuvos policija',
        maxGrade = 15,
        bossMenuMinGrade = 7,
        divisionsEnabled = true,
        defaultDeputyGrade = 9,
        permissionKeys = {
            { key = 'mdt_open', label = 'MDT atidarymas' },
            { key = 'mdt_search_basic', label = 'MDT paieška (bazinė)' },
            { key = 'mdt_search_full', label = 'MDT paieška (pilna)' },
            { key = 'mdt_fine', label = 'MDT baudos' },
            { key = 'mdt_wanted', label = 'MDT ieškomi' },
            { key = 'mdt_fingerprint', label = 'Pirštų atspaudai' },
            { key = 'mdt_arrest_record', label = 'Arešto įrašai' },
            { key = 'mdt_interrogation', label = 'Interrogacijos' },
            { key = 'cuff', label = 'Antrankiai' },
            { key = 'search_inventory', label = 'Kratos' },
            { key = 'division_admin', label = 'Divizijų valdymas' },
            { key = 'armory', label = 'Ginklinė' },
            { key = 'garage', label = 'Garažas' },
            { key = 'boss_menu', label = 'Vadovybės meniu' },
            { key = 'pd_siren_controller', label = 'Sirenos' },
            { key = 'pd_emergency_kit', label = 'Avarinė įranga' },
            { key = 'pd_doors', label = 'Durų užraktai' },
            { key = 'pd_craft', label = 'PD craft' },
            { key = 'mdt_cctv', label = 'CCTV' },
            { key = 'mdt_bodycam', label = 'Bodycam peržiūra' },
            { key = 'bodycam_wear', label = 'Bodycam nešiojimas' },
        },
    },
    ambulance = {
        label = 'Medikas',
        maxGrade = 10,
        bossMenuMinGrade = 4,
        divisionsEnabled = false,
        defaultDeputyGrade = 4,
        permissionKeys = {
            { key = 'boss_menu', label = 'Vadovybės meniu' },
            { key = 'garage', label = 'Garažas' },
            { key = 'stash', label = 'Sandėlis' },
        },
    },
    mechanic = {
        label = 'Mechanikas',
        maxGrade = 10,
        bossMenuMinGrade = 4,
        divisionsEnabled = false,
        defaultDeputyGrade = 4,
        permissionKeys = {
            { key = 'boss_menu', label = 'Vadovybės meniu' },
            { key = 'stash', label = 'Sandėlis' },
        },
    },
    taxi = {
        label = 'Taksi',
        maxGrade = 5,
        bossMenuMinGrade = 2,
        divisionsEnabled = false,
        defaultDeputyGrade = 1,
        permissionKeys = {
            { key = 'boss_menu', label = 'Vadovybės meniu' },
        },
    },
    ranger = {
        label = 'Gamtos apsauga',
        maxGrade = 8,
        bossMenuMinGrade = 3,
        divisionsEnabled = false,
        defaultDeputyGrade = 2,
        permissionKeys = {
            { key = 'boss_menu', label = 'Vadovybės meniu' },
            { key = 'garage', label = 'Garažas' },
            { key = 'stash', label = 'Sandėlis' },
        },
    },
}

--- Numatytosios policijos divizijos (seed DB)
Config.DefaultPoliceDivisions = {
    { id = 'lpm', label = 'LPM (mokymo padalinys)', abbr = 'LPM', description = 'Kursantai ir jaunesni pareigūnai', min_grade = 0, choosable = false, sort_order = 0 },
    { id = 'mp', label = 'Miesto patrulių divizija', abbr = 'MP', description = 'Kasdienis patruliavimas', min_grade = 4, choosable = true, sort_order = 10 },
    { id = 'kpd', label = 'Kelių policijos divizija', abbr = 'KPD', description = 'Eismo priežiūra', min_grade = 4, choosable = true, sort_order = 20 },
    { id = 'ktd', label = 'Kriminalinių tyrimų divizija', abbr = 'KTD', description = 'Sunkių nusikaltimų tyrimai', min_grade = 4, choosable = true, sort_order = 30 },
    { id = 'sor', label = 'Specialiųjų operacijų rinktinė', abbr = 'SOR', description = 'Elitinis taktinis padalinys', min_grade = 4, choosable = true, sort_order = 40 },
    { id = 'opd', label = 'Oro paramos divizija', abbr = 'OPD', description = 'Sraigtasparniai ir stebėjimas', min_grade = 4, choosable = true, sort_order = 50 },
    { id = 'kd', label = 'Kinologų divizija', abbr = 'KD', description = 'Tarnybiniai šunys', min_grade = 4, choosable = true, sort_order = 60 },
    { id = 'vtd', label = 'Vidaus tyrimų divizija', abbr = 'VTD', description = 'Policijos kontrolė', min_grade = 4, choosable = true, sort_order = 70 },
    { id = 'admin', label = 'Administracija', abbr = 'ADM', description = 'Vadovybė ir administracija', min_grade = 7, choosable = false, sort_order = 90 },
}

--- Senų divizijų ID → nauji (migracija)
Config.DivisionAliases = {
    patrol = 'mp',
    traffic = 'kpd',
    criminal = 'ktd',
    aro = 'sor',
    aras = 'sor',
    ARAS = 'sor',
}

Config.ManagementRadius = 12.0
