import type { Action, State } from './state';

export function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'open':
      return {
        ...state,
        hubOpen: true,
        catalogue: action.catalogue,
        data: action.data,
        shop: action.data.shop ?? action.shop ?? state.shop,
        nearby: action.nearby,
        locale: action.locale ?? state.locale,
        profile: { open: !action.data.progress.criminal_name, face: action.data.progress.criminal_avatar || 'face01' },
      };

    case 'closeAll':
      return { ...state, hubOpen: false, profile: { ...state.profile, open: false }, atmMenuOpen: false, safe: { ...state.safe, open: false } };

    case 'refresh':
      return { ...state, data: action.data, nearby: action.nearby ?? state.nearby };

    case 'nearby':
      return { ...state, nearby: action.nearby };

    case 'chatMessage':
      if (!state.data) return state;
      return { ...state, data: { ...state.data, chat: [...state.data.chat, action.message] } };

    case 'tickCooldowns': {
      if (!state.data) return state;
      let changed = false;
      const robberies = Object.fromEntries(
        Object.entries(state.data.robberies).map(([id, robbery]) => {
          if (robbery.cooldown > 0) {
            changed = true;
            return [id, { ...robbery, cooldown: robbery.cooldown - 1 }];
          }
          return [id, robbery];
        }),
      );
      return changed ? { ...state, data: { ...state.data, robberies } } : state;
    }

    case 'setTab':
      return { ...state, tab: action.tab };

    case 'selectHeist':
      return { ...state, selectedHeist: action.id };

    case 'search':
      return { ...state, search: action.value };

    case 'cartAdd': {
      const existing = state.cart.find((line) => line.name === action.item.name);
      const cart = existing
        ? state.cart.map((line) => (line === existing ? { ...line, qty: line.qty + 1 } : line))
        : [...state.cart, { ...action.item, qty: 1 }];
      return { ...state, cart };
    }

    case 'cartRemove':
      return { ...state, cart: state.cart.filter((_, index) => index !== action.index) };

    case 'cartClear':
      return { ...state, cart: [] };

    case 'profileOpen':
      return { ...state, profile: { open: true, face: action.face } };

    case 'profileClose':
      return { ...state, profile: { ...state.profile, open: false } };

    case 'profileFace':
      return { ...state, profile: { ...state.profile, face: action.face } };

    case 'profileSaved':
      if (!state.data) return state;
      return {
        ...state,
        profile: { open: false, face: action.face },
        data: { ...state.data, progress: { ...state.data.progress, criminal_name: action.name, criminal_avatar: action.face } },
      };

    case 'mission':
      return {
        ...state,
        mission: action.show
          ? { show: true, label: action.label ?? '', briefing: action.briefing ?? [], expanded: false, seconds: state.mission.seconds }
          : { ...state.mission, show: false },
      };

    case 'timer':
      return { ...state, mission: { ...state.mission, seconds: action.seconds } };

    case 'toggleBrief':
      return { ...state, mission: { ...state.mission, expanded: !state.mission.expanded } };

    case 'atmMenu':
      return { ...state, atmMenuOpen: action.show };

    case 'safeOpen':
      return { ...state, safe: { open: true, storeId: action.storeId, hint: action.hint, label: action.label } };

    case 'safeClose':
      return { ...state, safe: { ...state.safe, open: false } };

    case 'worldPrompt':
      return {
        ...state,
        worldPrompt: action.show
          ? { show: true, x: action.x ?? 0.5, y: action.y ?? 0.5, text: action.text ?? '', key: action.key ?? '' }
          : { ...state.worldPrompt, show: false },
      };
  }
}
