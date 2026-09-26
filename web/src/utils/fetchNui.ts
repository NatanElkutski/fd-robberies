import type { NuiCallback, NuiCallbacks } from '../types/protocol';
import { isEnvBrowser, resourceName } from './misc';

/**
 * Posts to a RegisterNUICallback handler on the client Lua side.
 * Only features' api.ts files may call this (see CLAUDE.md UI rules).
 */
export async function fetchNui<T = unknown>(name: NuiCallback, data?: NuiCallbacks[typeof name], mock?: T): Promise<T | null> {
  if (isEnvBrowser()) {
    return mock ?? null;
  }

  try {
    const response = await fetch(`https://${resourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data ?? {}),
    });
    return (await response.json()) as T;
  } catch {
    return null;
  }
}
