import { useEffect, useRef } from 'react';

/** setInterval that always calls the latest callback; pass `null` to pause. */
export function useInterval(callback: () => void, delayMs: number | null): void {
  const callbackRef = useRef(callback);
  callbackRef.current = callback;

  useEffect(() => {
    if (delayMs === null) {
      return;
    }
    const id = window.setInterval(() => callbackRef.current(), delayMs);
    return () => window.clearInterval(id);
  }, [delayMs]);
}
