/** Logų struktūra po „Admin-logai“ kategorijos */
export const LOG_LAYOUT = {
  anchorName: '📋 Admin-logai',
  anchorMatch: /admin[\s_-]?logai/i,
  categories: [
    {
      name: '🛡️ Discord · Saugumas',
      channels: [
        { name: 'discord-mod-logs', logType: 'mod', discord: true },
        { name: 'discord-antinuke-logs', logType: 'antinuke', discord: true },
        { name: 'discord-security-logs', logType: 'security', discord: true },
      ],
    },
    {
      name: '💬 Discord · Žinutės',
      channels: [
        { name: 'discord-message-logs', logType: 'message', discord: true },
      ],
    },
    {
      name: '👥 Discord · Nariai',
      channels: [
        { name: 'discord-member-logs', logType: 'member', discord: true },
        { name: 'discord-join-logs', logType: 'join', discord: true },
        { name: 'discord-role-logs', logType: 'role', discord: true },
      ],
    },
    {
      name: '📁 Discord · Serveris',
      channels: [
        { name: 'discord-channel-logs', logType: 'channel', discord: true },
        { name: 'discord-voice-logs', logType: 'voice', discord: true },
        { name: 'discord-webhook-logs', logType: 'webhook', discord: true },
      ],
    },
    {
      name: '🎮 FiveM · Žaidėjai',
      channels: [
        { name: 'fivem-join-leave', logType: 'join_leave', fivem: true },
        { name: 'fivem-chat-logs', logType: 'chat', fivem: true },
        { name: 'fivem-death-logs', logType: 'death', fivem: true },
        { name: 'fivem-revive-logs', logType: 'revive', fivem: true },
        { name: 'fivem-spawn-logs', logType: 'spawn', fivem: true },
      ],
    },
    {
      name: '💰 FiveM · Ekonomika',
      channels: [
        { name: 'fivem-bank-logs', logType: 'bank', fivem: true },
        { name: 'fivem-money-logs', logType: 'money', fivem: true },
        { name: 'fivem-inventory-logs', logType: 'inventory', fivem: true },
        { name: 'fivem-warehouse-logs', logType: 'warehouse', fivem: true },
      ],
    },
    {
      name: '🏢 FiveM · Frakcijos',
      channels: [
        { name: 'fivem-job-logs', logType: 'job', fivem: true },
        { name: 'fivem-gang-logs', logType: 'gang', fivem: true },
        { name: 'fivem-mission-logs', logType: 'mission', fivem: true },
      ],
    },
    {
      name: '🚗 FiveM · Transportas',
      channels: [
        { name: 'fivem-vehicle-logs', logType: 'vehicle', fivem: true },
      ],
    },
    {
      name: '⚙️ FiveM · Admin',
      channels: [
        { name: 'fivem-admin-logs', logType: 'admin', fivem: true },
        { name: 'fivem-security-logs', logType: 'security', fivem: true },
      ],
    },
  ],
};
