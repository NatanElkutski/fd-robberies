import { createContext, useCallback, useContext, useMemo, type ReactNode } from 'react';
import fallbackLocale from '../../../locales/he.json';
import { useStore } from '../store/StoreProvider';
import type { LocaleDictionary } from '../types/protocol';
import { formatString } from '../utils/format';

type Translate = (key: string, ...args: (string | number)[]) => string;

/** Flattens nested locale JSON into dotted keys, like ox_lib does. */
function flatten(source: Record<string, unknown>, prefix = '', target: LocaleDictionary = {}): LocaleDictionary {
  for (const [key, value] of Object.entries(source)) {
    const fullKey = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === 'object') {
      flatten(value as Record<string, unknown>, fullKey, target);
    } else if (typeof value === 'string') {
      target[fullKey] = value;
    }
  }
  return target;
}

// Used in the browser (npm run dev) and as a safety net if Lua sends no dictionary.
const FALLBACK = flatten(fallbackLocale as Record<string, unknown>);

const LocaleContext = createContext<Translate>((key) => key);

export function LocaleProvider({ children }: { children: ReactNode }) {
  const { locale } = useStore();
  const dictionary = useMemo(() => ({ ...FALLBACK, ...(locale ?? {}) }), [locale]);

  const t = useCallback<Translate>(
    (key, ...args) => {
      const template = dictionary[key];
      if (template === undefined) return key;
      return args.length ? formatString(template, args) : template;
    },
    [dictionary],
  );

  return <LocaleContext.Provider value={t}>{children}</LocaleContext.Provider>;
}

export const useLocale = (): Translate => useContext(LocaleContext);
