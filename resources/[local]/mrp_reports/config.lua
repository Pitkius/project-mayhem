Config = Config or {}

Config.Reports = {
    CooldownSeconds = 90,
    TitleMinLen = 4,
    TitleMaxLen = 80,
    MessageMinLen = 10,
    MessageMaxLen = 1200,
    MaxAttachments = 5,
    MaxStoredReports = 120,
    StaffPerms = { 'mod', 'admin', 'god' },
    --- F7 UI: „Admin panelė“ mygtukas (staff be šių teisių mato tik žaidėjo formą)
    AdminPanelPerms = { 'mod', 'admin', 'god' },

    OpenKey = 'F7',
    OpenKeyDescription = 'Atidaryti pagalbos centrą',

    Categories = {
        { id = 'player_violation', label = 'Žaidėjo pažeidimas', icon = 'violation', color = '#f87171', priority = 'high' },
        { id = 'bug', label = 'Klaida (Bug)', icon = 'bug', color = '#fbbf24', priority = 'medium' },
        { id = 'question', label = 'Klausimas', icon = 'question', color = '#93c5fd', priority = 'low' },
        { id = 'other', label = 'Kita', icon = 'other', color = '#c4b5fd', priority = 'medium' },
    },

    PriorityLabels = {
        low = 'Mažas',
        medium = 'Vidutinis',
        high = 'Aukštas',
    },

    StatusLabels = {
        waiting = 'Laukiama',
        in_progress = 'Nagrinėjama',
        resolved = 'Išspręsta',
        rejected = 'Atmesta',
    },
}
