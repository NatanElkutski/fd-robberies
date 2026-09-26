import { useLocale } from '../../../providers/LocaleProvider';
import type { RobberyCard } from '../../../types/protocol';
import { heistImage } from '../../../utils/assets';
import { formatClock } from '../../../utils/format';
import type { HeistStatus } from '../types';
import styles from './HeistCard.module.css';

interface Props {
  id: string;
  robbery: RobberyCard;
  status: HeistStatus;
  selected: boolean;
  onSelect: () => void;
  onStart: () => void;
}

export function HeistCard({ id, robbery, status, selected, onSelect, onStart }: Props) {
  const t = useLocale();
  const locked = status.kind === 'locked';
  const canStart = status.kind === 'available';
  const minCrew = robbery.minPlayers || 1;
  const crew = robbery.maxPlayers && robbery.maxPlayers !== minCrew ? `${minCrew}-${robbery.maxPlayers}` : `${minCrew}`;

  const statusText = {
    locked: () => t('ui.heists.level_required', robbery.level),
    busy: () => t('ui.heists.busy'),
    cooldown: () => t('ui.heists.cooldown', formatClock(status.kind === 'cooldown' ? status.seconds : 0)),
    available: () => t('ui.heists.available'),
  }[status.kind]();

  const buttonText = {
    locked: () => t('ui.heists.btn_locked', robbery.level),
    busy: () => t('ui.heists.btn_active'),
    cooldown: () => t('ui.heists.cooldown', formatClock(status.kind === 'cooldown' ? status.seconds : 0)),
    available: () => t('ui.heists.btn_start'),
  }[status.kind]();

  const classes = [styles.card, locked && styles.locked, selected && styles.selected].filter(Boolean).join(' ');

  return (
    <article className={classes} onClick={onSelect}>
      <div className={styles.hero} style={{ backgroundImage: `url('${heistImage(id)}')` }}>
        <div className={styles.shade} />
        <div className={styles.badges}>
          <span className={styles.badge}>👮 {robbery.minPolice || 0}</span>
          <span className={styles.badge}>◷ {Math.ceil((robbery.duration || 0) / 60)}</span>
          <span className={`${styles.badge} ${styles.crew}`}>👥 {crew}</span>
        </div>
        {locked && (
          <div className={styles.lock}>
            <span className={styles.lockIcon}>🔒</span>
            <b>{t('ui.heists.locked')}</b>
            <small>{t('ui.heists.lock_level', robbery.level)}</small>
          </div>
        )}
        <div className={styles.title}>
          <b>{robbery.label}</b>
          <small>{robbery.subtitle}</small>
        </div>
      </div>
      <div className={styles.quickInfo}>
        <span>{statusText}</span>
        <span>{t('ui.heists.xp', robbery.xpReward || 0)}</span>
      </div>
      <button
        type="button"
        className={styles.start}
        disabled={!canStart}
        onClick={(event) => {
          event.stopPropagation();
          if (canStart) onStart();
        }}
      >
        {buttonText}
      </button>
    </article>
  );
}
