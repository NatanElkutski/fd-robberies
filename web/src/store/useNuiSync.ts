import { useNuiEvent } from '../hooks/useNuiEvent';
import type { HubData, ShopConfig } from '../types/protocol';
import { useDispatch } from './StoreProvider';

/**
 * Lua can't tell an empty array from an empty object, so an empty list may arrive as {}.
 * Normalize every list before it reaches components.
 */
function asArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[];
  if (value && typeof value === 'object') return Object.values(value) as T[];
  return [];
}

function normalizeShop(shop: ShopConfig | undefined): ShopConfig {
  return {
    items: asArray(shop?.items),
    allowCash: shop?.allowCash !== false,
    allowBank: shop?.allowBank !== false,
  };
}

function normalizeData(data: HubData): HubData {
  return {
    ...data,
    robberies: data.robberies ?? {},
    xpRewards: data.xpRewards ?? {},
    chat: asArray(data.chat),
    crew: {
      ...data.crew,
      members: asArray(data.crew?.members),
      invites: asArray(data.crew?.invites),
    },
    shop: normalizeShop(data.shop),
  };
}

/** Maps every Lua -> UI message onto a store action. Mounted once in App. */
export function useNuiSync(): void {
  const dispatch = useDispatch();

  useNuiEvent('open', (msg) =>
    dispatch({
      type: 'open',
      catalogue: msg.config ?? {},
      data: normalizeData(msg.data),
      shop: normalizeShop(msg.shop ?? msg.data?.shop),
      nearby: asArray(msg.nearby),
      locale: msg.locale,
    }),
  );
  useNuiEvent('close', () => dispatch({ type: 'closeAll' }));
  useNuiEvent('dataRefresh', (msg) => dispatch({ type: 'refresh', data: normalizeData(msg.data), nearby: asArray(msg.nearby) }));
  useNuiEvent('nearby', (msg) => dispatch({ type: 'nearby', nearby: asArray(msg.nearby) }));
  useNuiEvent('lobbyMessage', (msg) => dispatch({ type: 'chatMessage', message: msg.message }));
  useNuiEvent('mission', (msg) => dispatch({ type: 'mission', show: msg.show, label: msg.label, briefing: asArray<string>(msg.briefing) }));
  useNuiEvent('timer', (msg) => dispatch({ type: 'timer', seconds: msg.seconds }));
  useNuiEvent('toggleBrief', () => dispatch({ type: 'toggleBrief' }));
  useNuiEvent('atmMenu', (msg) => dispatch({ type: 'atmMenu', show: msg.show }));
  useNuiEvent('safeInput', (msg) => dispatch({ type: 'safeOpen', storeId: msg.storeId, hint: msg.hint, label: msg.label }));
  useNuiEvent('worldPrompt', (msg) => dispatch({ type: 'worldPrompt', show: msg.show, x: msg.x, y: msg.y, text: msg.text, key: msg.key }));
}
