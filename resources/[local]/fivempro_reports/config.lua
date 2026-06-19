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

    OpenKey = 'F7',
    OpenKeyDescription = 'Atidaryti pagalbos centrą',

    Categories = {
        { id = 'player_violation', label = 'Žaidėjo pažeidimas', icon = '⚠️', color = '#f87171', priority = 'high' },
        { id = 'bug', label = 'Klaida (Bug)', icon = '🐛', color = '#fbbf24', priority = 'medium' },
        { id = 'money_items', label = 'Pinigų / daiktų problema', icon = '💰', color = '#f87171', priority = 'high' },
        { id = 'vehicle', label = 'Transporto problema', icon = '🚗', color = '#60a5fa', priority = 'medium' },
        { id = 'property', label = 'NT / būsto problema', icon = '🏠', color = '#60a5fa', priority = 'medium' },
        { id = 'gang', label = 'Gaujos problema', icon = '👥', color = '#a78bfa', priority = 'medium' },
        { id = 'police', label = 'Policijos problema', icon = '🚔', color = '#38bdf8', priority = 'medium' },
        { id = 'medic', label = 'Medikų problema', icon = '🚑', color = '#34d399', priority = 'medium' },
        { id = 'question', label = 'Klausimas administracijai', icon = '❓', color = '#93c5fd', priority = 'low' },
        { id = 'other', label = 'Kita', icon = '📝', color = '#c4b5fd', priority = 'medium' },
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
