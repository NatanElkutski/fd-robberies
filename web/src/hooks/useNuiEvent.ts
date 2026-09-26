import { useEffect, useRef } from 'react';
import type { NuiAction, NuiMessages } from '../types/protocol';

/**
 * Subscribes to one NUI message action sent from Lua (FD.Nui.Send).
 * The only place in the UI that listens to window "message" events.
 */
export function useNuiEvent<A extends NuiAction>(action: A, handler: (payload: NuiMessages[A]) => void): void {
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  useEffect(() => {
    const listener = (event: MessageEvent<{ action?: string } & Record<string, unknown>>) => {
      if (event.data?.action === action) {
        handlerRef.current(event.data as unknown as NuiMessages[A]);
      }
    };
    window.addEventListener('message', listener);
    return () => window.removeEventListener('message', listener);
  }, [action]);
}
