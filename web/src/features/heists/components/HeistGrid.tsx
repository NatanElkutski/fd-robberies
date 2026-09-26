import { useMemo } from 'react';
import { useInterval } from '../../../hooks/useInterval';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import type { RobberyCard, RobberyState } from '../../../types/protocol';
import { startHeist } from '../api';
import type { HeistStatus } from '../types';
import { HeistCard } from './HeistCard';
import styles from './HeistGrid.module.css';

function statusOf(robbery: RobberyCard, state: RobberyState | undefined, level: number): HeistStatus {
  if (level < robbery.level) return { kind: 'locked', level: robbery.level };
  if (state?.active) return { kind: 'busy' };
  if (state && state.cooldown > 0) return { kind: 'cooldown', seconds: state.cooldown };
  return { kind: 'available' };
}

/** Robbery cards: unlocked first, then by level; filtered by the search box. */
export function HeistGrid() {
  const { catalogue, data, search, selectedHeist, hubOpen } = useStore();
  const dispatch = useDispatch();
  const level = data?.progress.level ?? 1;

  // cooldowns count down locally while the menu is open
  useInterval(() => dispatch({ type: 'tickCooldowns' }), hubOpen ? 1000 : null);

  const heists = useMemo(() => {
    const query = search.trim().toLowerCase();
    return Object.entries(catalogue)
      .filter(([, robbery]) => !query || robbery.label.toLowerCase().includes(query) || robbery.subtitle.toLowerCase().includes(query))
      .sort(([, a], [, b]) => {
        const aOpen = level >= a.level;
        const bOpen = level >= b.level;
        if (aOpen !== bOpen) return aOpen ? -1 : 1;
        return a.level - b.level;
      });
  }, [catalogue, search, level]);

  return (
    <div className={styles.grid}>
      {heists.map(([id, robbery]) => (
        <HeistCard
          key={id}
          id={id}
          robbery={robbery}
          status={statusOf(robbery, data?.robberies[id], level)}
          selected={selectedHeist === id}
          onSelect={() => dispatch({ type: 'selectHeist', id })}
          onStart={() => {
            dispatch({ type: 'selectHeist', id });
            void startHeist(id);
          }}
        />
      ))}
    </div>
  );
}
