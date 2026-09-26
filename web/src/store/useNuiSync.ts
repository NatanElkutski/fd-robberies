import { useNuiEvent } from '../hooks/useNuiEvent';
import { useDispatch } from './StoreProvider';

/** Maps every Lua -> UI message onto a store action. Mounted once in App. */
export function useNuiSync(): void {
  const dispatch = useDispatch();

  useNuiEvent('open', (msg) =>
    dispatch({ type: 'open', catalogue: msg.config, data: msg.data, shop: msg.shop, nearby: msg.nearby ?? [], locale: msg.locale }),
  );
  useNuiEvent('close', () => dispatch({ type: 'closeAll' }));
  useNuiEvent('dataRefresh', (msg) => dispatch({ type: 'refresh', data: msg.data, nearby: msg.nearby }));
  useNuiEvent('nearby', (msg) => dispatch({ type: 'nearby', nearby: msg.nearby ?? [] }));
  useNuiEvent('lobbyMessage', (msg) => dispatch({ type: 'chatMessage', message: msg.message }));
  useNuiEvent('mission', (msg) => dispatch({ type: 'mission', show: msg.show, label: msg.label, briefing: msg.briefing }));
  useNuiEvent('timer', (msg) => dispatch({ type: 'timer', seconds: msg.seconds }));
  useNuiEvent('toggleBrief', () => dispatch({ type: 'toggleBrief' }));
  useNuiEvent('atmMenu', (msg) => dispatch({ type: 'atmMenu', show: msg.show }));
  useNuiEvent('safeInput', (msg) => dispatch({ type: 'safeOpen', storeId: msg.storeId, hint: msg.hint, label: msg.label }));
}
