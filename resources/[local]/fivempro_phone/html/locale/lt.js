/** Lietuviški tekstai — lengvai plėsti ar keisti */
window.PhoneLocale = {
  contacts: {
    title: "Kontaktai",
    search: "Ieškoti kontaktų…",
    add: "Naujas kontaktas",
    name: "Vardas",
    number: "Telefono nr.",
    save: "Išsaugoti",
    edit: "Redaguoti",
    delete: "Šalinti",
    call: "Skambinti",
    message: "Rašyti",
    empty: "Kontaktų sąrašas tuščias.",
    confirmDelete: "Pašalinti kontaktą?",
  },
  messages: {
    title: "Žinutės",
    search: "Ieškoti pokalbių…",
    new: "Nauja žinutė",
    placeholder: "Rašykite žinutę…",
    send: "Siųsti",
    empty: "Pokalbių dar nėra.",
    to: "Kam",
    open: "Atidaryti",
  },
  calls: {
    title: "Skambučiai",
    dial: "Numeris",
    call: "Skambinti",
    hangup: "Baigti",
    yourNumber: "Jūsų nr.",
    fromContacts: "Kontaktai",
    recent: "Naujausi",
    keypad: "Klaviatūra",
  },
  camera: {
    title: "Kamera",
    gallery: "Galerija",
    capture: "Fotografuoti",
    flip: "Keisti kamerą",
    flash: "Blykstė",
    zoom: "Priartinimas",
  },
  carplay: {
    title: "CarPlay",
    nowPlaying: "Dabar groja",
    addUrl: "Nuoroda ar grojaraštis",
    urlPlaceholder: "YouTube / Spotify nuoroda ar grojaraštis",
    inVehicleOnly: "CarPlay veikia tik automobilyje",
    emptyTitle: "Niekas negroja",
  },
  ads: {
    title: "Skelbimai",
    post: "Naujas skelbimas",
    titleField: "Antraštė",
    category: "Kategorija",
    price: "Kaina ($)",
    body: "Aprašymas",
    publish: "Paskelbti",
    callAuthor: "Skambinti",
    messageAuthor: "Rašyti",
    empty: "Skelbimų nėra.",
    mine: "Mano",
    delete: "Šalinti",
    confirmDelete: "Pašalinti skelbimą?",
    free: "Nemokamai",
  },
  common: {
    back: "Atgal",
    cancel: "Atšaukti",
    loading: "Kraunama…",
    error: "Klaida",
    saved: "Išsaugota",
  },
  notes: {
    save: "Išsaugoti",
    saving: "Saugoma…",
    saved: "Išsaugota",
    error: "Nepavyko išsaugoti.",
  },
  bank: {
    title: "BANKAS",
    transfer: "Pervesti",
    deposit: "Įnešti",
    history: "Istorija",
    saved: "Operacija atlikta",
  },
};

window.t = function t(key, fallback) {
  const parts = String(key || "").split(".");
  let cur = window.PhoneLocale;
  for (const p of parts) {
    if (!cur || typeof cur !== "object") return fallback ?? key;
    cur = cur[p];
  }
  return cur ?? fallback ?? key;
};
