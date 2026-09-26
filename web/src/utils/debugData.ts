import type { NuiAction, NuiMessages } from '../types/protocol';

/** Sends fake Lua messages so the UI can be developed in a normal browser (npm run dev). */
const send = <A extends NuiAction>(action: A, payload: NuiMessages[A], delayMs: number) =>
  window.setTimeout(() => window.dispatchEvent(new MessageEvent('message', { data: { action, ...payload } })), delayMs);

const robbery = (label: string, subtitle: string, level: number, minPolice: number, minutes: number, minPlayers: number, xpReward: number, maxPlayers?: number) => ({
  label,
  subtitle,
  level,
  minPolice,
  duration: minutes * 60,
  minPlayers,
  maxPlayers,
  xpReward,
});

export function debugData(): void {
  document.body.style.background = '#2a3138';

  send(
    'open',
    {
      config: {
        store: robbery('שוד חנות 24/7', 'STORE HOLDUP', 1, 0, 10, 3, 220, 3),
        atm: robbery('פריצת כספומט', 'ATM HIT', 1, 0, 10, 1, 250, 2),
        house: robbery('פריצה לבית יוקרה', 'LUXURY HOUSE', 2, 0, 12, 2, 400),
        fleeca: robbery('שוד בנק פליקה', 'FLEECA BANK', 3, 2, 15, 3, 650),
        pacific: robbery('Pacific Standard', 'FINAL HEIST', 10, 6, 25, 6, 2200),
      },
      data: {
        progress: { xp: 1340, completed: 4, level: 2, criminal_name: 'BLACK FOX', criminal_avatar: 'face03' },
        robberies: {
          store: { active: false, cooldown: 0, requiredLevel: 1 },
          atm: { active: false, cooldown: 95, requiredLevel: 1 },
          house: { active: true, cooldown: 0, requiredLevel: 2 },
          fleeca: { active: false, cooldown: 0, requiredLevel: 3 },
          pacific: { active: false, cooldown: 0, requiredLevel: 10 },
        },
        xpPerLevel: 1000,
        xpRewards: { store: 220, atm: 250, house: 400, fleeca: 650, pacific: 2200 },
        crew: {
          leader: 1,
          isLeader: true,
          members: [
            { id: 1, name: 'BLACK FOX', leader: true },
            { id: 7, name: 'Viper', leader: false },
          ],
          invites: [{ id: 12, name: '<img src=x onerror=alert(1)>' }],
        },
        chat: [{ id: 7, name: 'Viper', text: 'מישהו לפליקה?', time: 0 }],
        shop: {
          allowCash: true,
          allowBank: true,
          items: [
            { name: 'rope', price: 850, icon: '🪢' },
            { name: 'lockpick', price: 450, icon: '🗝️' },
            { name: 'thermite', price: 2200, icon: '💣' },
            { name: 'drill', price: 1800, icon: '🛠️' },
            { name: 'electronickit', price: 1450, icon: '💻' },
            { name: 'trojan_usb', price: 1250, icon: '💾' },
            { name: 'screwdriverset', price: 700, icon: '🧰' },
            { name: 'security_card_01', price: 3000, icon: '💳' },
          ],
        },
      },
      shop: { allowCash: true, allowBank: true, items: [] },
      nearby: [{ id: 21, name: 'Nearby Guy', distance: 3.4 }],
    },
    300,
  );

  send('mission', { show: true, label: 'פריצת כספומט', briefing: ['מצא כל כספומט בעיר.', 'ALT על הכספומט ובחר שיטה.', 'סיים לפני שהזמן נגמר.'] }, 400);
  send('timer', { seconds: 512 }, 500);

  // ?prompt in the URL shows only the floating world prompt (hub closed) for visual checks
  if (new URLSearchParams(window.location.search).has('prompt')) {
    send('close', {} as Record<string, never>, 600);
    send('worldPrompt', { show: true, x: 0.42, y: 0.4, text: 'חבר את הוו לרכב', key: 'E' }, 700);
  }
}
