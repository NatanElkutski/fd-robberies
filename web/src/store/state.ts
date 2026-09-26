import type { ChatMessage, HubData, LocaleDictionary, NearbyPlayer, RobberyCard, ShopConfig, ShopItem } from '../types/protocol';

export type HubTab = 'heists' | 'shop';

export interface CartLine extends ShopItem {
  qty: number;
}

export interface State {
  hubOpen: boolean;
  tab: HubTab;
  catalogue: Record<string, RobberyCard>;
  data: HubData | null;
  shop: ShopConfig;
  nearby: NearbyPlayer[];
  selectedHeist: string | null;
  search: string;
  cart: CartLine[];
  profile: { open: boolean; face: string };
  mission: { show: boolean; label: string; briefing: string[]; expanded: boolean; seconds: number };
  atmMenuOpen: boolean;
  safe: { open: boolean; storeId: number | null; hint: string; label: string };
  locale: LocaleDictionary | null;
  worldPrompt: { show: boolean; x: number; y: number; text: string; key: string };
}

export const initialState: State = {
  hubOpen: false,
  tab: 'heists',
  catalogue: {},
  data: null,
  shop: { items: [], allowCash: true, allowBank: true },
  nearby: [],
  selectedHeist: null,
  search: '',
  cart: [],
  profile: { open: false, face: 'face01' },
  mission: { show: false, label: '', briefing: [], expanded: false, seconds: 0 },
  atmMenuOpen: false,
  safe: { open: false, storeId: null, hint: '', label: '' },
  locale: null,
  worldPrompt: { show: false, x: 0, y: 0, text: '', key: '' },
};

export type Action =
  | { type: 'open'; catalogue: Record<string, RobberyCard>; data: HubData; shop: ShopConfig; nearby: NearbyPlayer[]; locale?: LocaleDictionary }
  | { type: 'closeAll' }
  | { type: 'refresh'; data: HubData; nearby: NearbyPlayer[] }
  | { type: 'nearby'; nearby: NearbyPlayer[] }
  | { type: 'chatMessage'; message: ChatMessage }
  | { type: 'tickCooldowns' }
  | { type: 'setTab'; tab: HubTab }
  | { type: 'selectHeist'; id: string }
  | { type: 'search'; value: string }
  | { type: 'cartAdd'; item: ShopItem }
  | { type: 'cartRemove'; index: number }
  | { type: 'cartClear' }
  | { type: 'profileOpen'; face: string }
  | { type: 'profileClose' }
  | { type: 'profileFace'; face: string }
  | { type: 'profileSaved'; name: string; face: string }
  | { type: 'mission'; show: boolean; label?: string; briefing?: string[] }
  | { type: 'timer'; seconds: number }
  | { type: 'toggleBrief' }
  | { type: 'atmMenu'; show: boolean }
  | { type: 'safeOpen'; storeId: number; hint: string; label: string }
  | { type: 'safeClose' }
  | { type: 'worldPrompt'; show: boolean; x?: number; y?: number; text?: string; key?: string };
