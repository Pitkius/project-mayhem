(function () {
  const paths = {
    home: '<path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1v-9.5Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" fill="none"/>',
    transfer:
      '<path d="M5 12h11M13 8l4 4-4 4M19 5v14" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
    history:
      '<circle cx="12" cy="12" r="8" stroke="currentColor" stroke-width="1.7" fill="none"/><path d="M12 8v4l3 2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" fill="none"/>',
    deposit:
      '<path d="M12 4v11M8 11l4 4 4-4M5 20h14" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
    bell:
      '<path d="M12 5a4 4 0 0 1 4 4v2.2c0 .8.3 1.6.8 2.2l.4.5H7l.4-.5c.5-.6.8-1.4.8-2.2V9a4 4 0 0 1 4-4Z" stroke="currentColor" stroke-width="1.6" fill="none"/><path d="M10 18a2 2 0 0 0 4 0" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" fill="none"/>',
    eye:
      '<path d="M3 12s3.5-6 9-6 9 6 9 6-3.5 6-9 6-9-6-9-6Z" stroke="currentColor" stroke-width="1.6" fill="none"/><circle cx="12" cy="12" r="2.5" stroke="currentColor" stroke-width="1.6" fill="none"/>',
    eyeOff:
      '<path d="M4 4l16 16M10.2 10.9A3 3 0 0 0 12 15a3 3 0 0 0 2.8-4.1M7.5 7.7C5.7 8.9 4.3 10.6 3 12c1.8 3 5 6 9 6 1.4 0 2.7-.4 3.9-1" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" fill="none"/>',
    check:
      '<path d="M6 12.5 10 16.5 18 8" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
    shield:
      '<path d="M12 3 6 5.5v5.8c0 4 2.6 6.8 6 8.7 3.4-1.9 6-4.7 6-8.7V5.5L12 3Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" fill="none"/>',
    transferOut:
      '<path d="M7 7h9M13 4l3 3-3 3M5 17h9M11 14l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
    transferIn:
      '<path d="M17 7H8M12 4 9 7l3 3M19 17h-9m4-3-3 3 3-3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
    salary:
      '<rect x="5" y="6" width="14" height="12" rx="2" stroke="currentColor" stroke-width="1.6" fill="none"/><path d="M9 10h6M9 13h4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" fill="none"/>',
    payment:
      '<path d="M6 8h12l-1.2 8H7.2L6 8Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" fill="none"/><path d="M9 8V6a3 3 0 0 1 6 0v2" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" fill="none"/>',
    fine:
      '<path d="M12 8v5M12 16.2h.01" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" fill="none"/><path d="M12 3 4 19h16L12 3Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" fill="none"/>',
    other:
      '<rect x="6" y="5" width="12" height="14" rx="2" stroke="currentColor" stroke-width="1.6" fill="none"/><path d="M9 10h6M9 13h4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" fill="none"/>',
  };

  window.BankIcon = function BankIcon(name, className) {
    const body = paths[name] || paths.other;
    const cls = className ? ` bank-svg ${className}` : " bank-svg";
    return `<span class="bank-svg-wrap${cls}" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">${body}</svg></span>`;
  };
})();
