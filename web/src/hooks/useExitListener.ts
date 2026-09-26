import { useEffect, useRef } from 'react';

/** Calls `onExit` when Escape is released. */
export function useExitListener(onExit: () => void): void {
  const exitRef = useRef(onExit);
  exitRef.current = onExit;

  useEffect(() => {
    const listener = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        exitRef.current();
      }
    };
    document.addEventListener('keyup', listener);
    return () => document.removeEventListener('keyup', listener);
  }, []);
}
