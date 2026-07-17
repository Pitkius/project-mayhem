/** Deklaratyvi moderni Discord serverio struktūra (idempotent setup). */

export const SERVER_LAYOUT = {
  categories: {
    start: {
      name: '📌・PRADŽIA',
      match: /pradz|start|welcome/i,
      channels: [
        { key: 'welcome', name: '👋・sveiki-atvykę', type: 'text', readOnly: true, match: /sveiki|welcome/i },
        { key: 'news', name: '📢・naujienos', type: 'text', readOnly: true, match: /naujien/i },
        { key: 'sneakpeek', name: '👀・sneak-peek', type: 'text', readOnly: true, match: /sneak.?peek|sneakpeek/i },
        { key: 'howto', name: '🧭・kaip-pradėti', type: 'text', readOnly: true, match: /kaip.?prad/i },
        { key: 'faq', name: '❓・dažniausi-klausimai', type: 'text', readOnly: true, match: /dazniaus|faq|klausim/i },
        { key: 'roles', name: '🎭・pasirink-roles', type: 'text', readOnly: true, match: /pasirink.?rol|roles?/i },
      ],
    },
    rules: {
      name: '📚・TAISYKLĖS',
      match: /taisyk|rules/i,
      channels: [
        { key: 'rules_general', name: '📖・bendros-taisyklės', type: 'text', readOnly: true, match: /bendros.?taisyk/i },
        { key: 'rules_rp', name: '🎭・roleplay-taisyklės', type: 'text', readOnly: true, match: /roleplay.?taisyk/i },
        { key: 'rules_traffic', name: '🚗・transporto-taisyklės', type: 'text', readOnly: true, match: /transporto.?taisyk/i },
        { key: 'rules_crime', name: '🔫・nusikaltimų-ir-kovų-taisyklės', type: 'text', readOnly: true, match: /nusikalt|kovu.?taisyk/i },
        { key: 'rules_gov', name: '🚓・valstybinių-frakcijų-taisyklės', type: 'text', readOnly: true, match: /valstyb|frakc.*taisyk/i },
        { key: 'rules_gangs', name: '🏴・nelegalių-grupuočių-taisyklės', type: 'text', readOnly: true, match: /nelegal|grupuoc/i },
        { key: 'rules_eco', name: '💰・ekonomikos-ir-turto-taisyklės', type: 'text', readOnly: true, match: /ekonomik|turto.?taisyk/i },
        { key: 'rules_voice', name: '🎙️・bendravimo-ir-balso-taisyklės', type: 'text', readOnly: true, match: /bendravim|balso.?taisyk/i },
        { key: 'rules_admin', name: '🛡️・administracijos-ir-reportų-taisyklės', type: 'text', readOnly: true, match: /administrac.*taisyk|reportu.?taisyk/i },
        { key: 'rules_punish', name: '⚠️・bausmės-ir-apskundimai', type: 'text', readOnly: true, match: /bausm|apskund/i },
      ],
    },
    community: {
      name: '💬・BENDRUOMENĖ',
      match: /bendruomen|community|chat/i,
      channels: [
        { key: 'general', name: '💬・bendras', type: 'text', match: /^💬?・?bendras$|general|chat$/i },
        { key: 'media', name: '📷・media', type: 'text', match: /media|nuotrauk/i },
        { key: 'suggestions', name: '💡・pasiūlymai', type: 'text', match: /pasiulym/i },
        { key: 'bugs', name: '🐞・bug-report', type: 'text', match: /bug/i },
        { key: 'offtopic', name: '🎉・off-topic', type: 'text', match: /off.?topic/i },
        { key: 'voice1', name: '🔊・Bendras', type: 'voice', match: /^🔊?・?Bendras$/i },
        { key: 'voice2', name: '🔊・Bendras 2', type: 'voice', match: /Bendras\s*2/i },
        { key: 'chill', name: '🌙・Chill', type: 'voice', match: /chill/i },
      ],
    },
    applications: {
      name: '📝・ANKETOS',
      match: /anket|application/i,
      channels: [
        { key: 'applications', name: '📋・anketos', type: 'text', readOnly: true, match: /^📋?・?anketos$|anketos$/i },
      ],
    },
    factions: {
      name: '🏢・FRAKCIJOS',
      match: /frakcij|factions?/i,
      channels: [
        { key: 'faction_police', name: '🚓・policija', type: 'text', faction: 'police', readOnly: true, match: /policij/i },
        { key: 'faction_ems', name: '🚑・medikai', type: 'text', faction: 'ems', readOnly: true, match: /medik/i },
        { key: 'faction_mechanic', name: '🔧・mechanikai', type: 'text', faction: 'mechanic', readOnly: true, match: /mechanik/i },
        { key: 'faction_taxi', name: '🚕・taxi', type: 'text', faction: 'taxi', readOnly: true, match: /taxi/i },
      ],
    },
    tickets: {
      name: '🎫・TICKETAI',
      match: /ticket/i,
      private: true,
      channels: [
        { key: 'ticket_chat', name: '🎫・ticket-chat', type: 'text', match: /ticket.?chat|ticketai/i },
      ],
    },
    archive: {
      name: '📦・SENAS SERVERIO ARCHYVAS',
      match: /archyv|archive/i,
      private: true,
      channels: [],
    },
  },
};

export const APPLICATION_TYPES = [
  {
    id: 'admin',
    label: 'Administracijos anketa',
    emoji: '🛡️',
    buttonLabel: 'Admin anketa',
    description: 'Prašymas tapti serverio administratoriumi.',
  },
  {
    id: 'faction_leader',
    label: 'Frakcijų vadovo anketa',
    emoji: '👑',
    buttonLabel: 'Frakcijų vadovas',
    description: 'Prašymas tapti valstybines frakcijos vadovu.',
  },
  {
    id: 'police',
    label: 'Policijos anketa',
    emoji: '🚓',
    buttonLabel: 'Pildyti anketą',
    description: 'Prašymas prisijungti prie Policijos.',
    faction: 'police',
  },
  {
    id: 'ems',
    label: 'Medikų anketa',
    emoji: '🚑',
    buttonLabel: 'Pildyti anketą',
    description: 'Prašymas prisijungti prie Medikų.',
    faction: 'ems',
  },
  {
    id: 'mechanic',
    label: 'Mechanikų anketa',
    emoji: '🔧',
    buttonLabel: 'Pildyti anketą',
    description: 'Prašymas prisijungti prie Mechanikų.',
    faction: 'mechanic',
  },
  {
    id: 'taxi',
    label: 'Taxi anketa',
    emoji: '🚕',
    buttonLabel: 'Pildyti anketą',
    description: 'Prašymas prisijungti prie Taxi.',
    faction: 'taxi',
  },
];

export const TICKET_CATEGORIES = [
  { id: 'help', label: 'Žaidėjo pagalba', emoji: '🆘' },
  { id: 'tech', label: 'Techninė problema', emoji: '🛠️' },
  { id: 'bug', label: 'Bug pranešimas', emoji: '🐞' },
  { id: 'player_report', label: 'Žaidėjo skundas', emoji: '📢' },
  { id: 'admin_report', label: 'Administracijos skundas', emoji: '🛡️' },
  { id: 'appeal', label: 'Bausmės apskundimas', emoji: '⚖️' },
  { id: 'unban', label: 'Unban prašymas', emoji: '🔓' },
  { id: 'shop', label: 'Parduotuvė / mokėjimas', emoji: '💳' },
  { id: 'faction', label: 'Frakcijos klausimas', emoji: '🏢' },
  { id: 'other', label: 'Kita problema', emoji: '❓' },
];

export const RULE_PLACEHOLDERS = {
  rules_general: {
    title: 'Bendros taisyklės',
    body: 'Čia bus bendros serverio taisyklės.\n\nRedaguok šį embed arba pakeisk žinutę pagal jūsų projekto taisykles.',
  },
  rules_rp: {
    title: 'Roleplay taisyklės',
    body: 'Čia bus RP taisyklės (RDM, VDM, NLR, metagaming ir kt.).\n\nAdministratorius gali įklijuoti galutinį tekstą.',
  },
  rules_traffic: {
    title: 'Transporto taisyklės',
    body: 'Čia bus transporto ir eismo taisyklės.',
  },
  rules_crime: {
    title: 'Nusikaltimų ir kovų taisyklės',
    body: 'Čia bus ginklų, apiplėšimų ir PvP taisyklės.',
  },
  rules_gov: {
    title: 'Valstybinių frakcijų taisyklės',
    body: 'Čia bus PD / EMS / valstybinių tarnybų taisyklės.',
  },
  rules_gangs: {
    title: 'Nelegalių grupuočių taisyklės',
    body: 'Čia bus gaujų ir nelegalios veiklos taisyklės.',
  },
  rules_eco: {
    title: 'Ekonomikos ir turto taisyklės',
    body: 'Čia bus pinigų, turto ir prekybos taisyklės.',
  },
  rules_voice: {
    title: 'Bendravimo ir balso taisyklės',
    body: 'Čia bus Discord / voice chat elgesio taisyklės.',
  },
  rules_admin: {
    title: 'Administracijos ir reportų taisyklės',
    body: 'Čia bus kaip kreiptis į administraciją ir reportuoti.',
  },
  rules_punish: {
    title: 'Bausmės ir apskundimai',
    body: 'Čia bus bausmių sistema ir apskundimo tvarka.',
  },
};
