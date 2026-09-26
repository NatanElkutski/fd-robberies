/**
 * The NUI contract with the Lua side. Every message Lua sends (FD.Nui.Send) and every
 * callback the UI posts (RegisterNUICallback) is declared here — keep both sides in sync.
 */

// ---------- data shapes ----------

export interface RobberyCard {
  label: string;
  subtitle: string;
  level: number;
  minPolice: number;
  duration: number; // seconds
  minPlayers: number;
  maxPlayers?: number;
  xpReward: number;
}

export interface RobberyState {
  active: boolean;
  cooldown: number; // seconds left
  requiredLevel: number;
}

export interface Progress {
  xp: number;
  completed: number;
  level: number;
  criminal_name?: string | null;
  criminal_avatar: string; // 'face01'..'face12'
}

export interface CrewMember {
  id: number;
  name: string;
  leader: boolean;
}

export interface CrewInvite {
  id: number;
  name: string;
}

export interface Crew {
  leader: number;
  members: CrewMember[];
  invites: CrewInvite[];
  isLeader: boolean;
}

export interface ChatMessage {
  id: number;
  name: string;
  text: string;
  time: number;
}

export interface ShopItem {
  name: string;
  price: number;
  icon: string;
}

export interface ShopConfig {
  items: ShopItem[];
  allowCash: boolean;
  allowBank: boolean;
}

export interface NearbyPlayer {
  id: number;
  name: string;
  distance: number;
}

export interface HubData {
  progress: Progress;
  robberies: Record<string, RobberyState>;
  xpPerLevel: number;
  xpRewards: Record<string, number>;
  crew: Crew;
  chat: ChatMessage[];
  shop: ShopConfig;
}

export type LocaleDictionary = Record<string, string>;

// ---------- Lua -> UI messages ----------

export interface NuiMessages {
  open: {
    config: Record<string, RobberyCard>;
    data: HubData;
    shop: ShopConfig;
    nearby: NearbyPlayer[];
    locale?: LocaleDictionary;
  };
  close: Record<string, never>;
  dataRefresh: { data: HubData; nearby: NearbyPlayer[] };
  nearby: { nearby: NearbyPlayer[] };
  lobbyMessage: { message: ChatMessage };
  mission: { show: boolean; label?: string; briefing?: string[] };
  timer: { seconds: number };
  toggleBrief: Record<string, never>;
  atmMenu: { show: boolean };
  safeInput: { storeId: number; hint: string; label: string };
}

export type NuiAction = keyof NuiMessages;

// ---------- UI -> Lua callbacks ----------

export type AtmMethod = 'rope' | 'explosive' | 'drill';
export type PaymentMethod = 'cash' | 'bank';

export interface NuiCallbacks {
  ready: Record<string, never>;
  uiError: { message: string };
  close: Record<string, never>;
  start: { id: string };
  endMission: Record<string, never>;
  buyItem: { item: string; paymentMethod: PaymentMethod };
  saveCriminalProfile: { name: string; avatar: string };
  crewInvite: { id: number };
  crewAccept: { id: number };
  crewLeave: Record<string, never>;
  lobbyMessage: { text: string };
  chatFocus: Record<string, never>;
  refreshNearby: Record<string, never>;
  safeCancel: Record<string, never>;
  safeSubmit: { storeId: number; code: string };
  atmChoose: { method: AtmMethod };
  atmCancel: Record<string, never>;
}

export type NuiCallback = keyof NuiCallbacks;
