import { useLocale } from '../../../providers/LocaleProvider';
import { useStore } from '../../../store/StoreProvider';
import { formatClock } from '../../../utils/format';
import styles from './MissionHud.module.css';

/** Always-on-screen robbery HUD: timer, first objective, and the B-toggled briefing. */
export function MissionHud() {
  const t = useLocale();
  const { mission } = useStore();
  if (!mission.show) return null;

  return (
    <aside className={`${styles.hud} ${mission.expanded ? styles.expanded : ''}`}>
      <div className={styles.hint}>
        <kbd>B</kbd>
        <span>{t('ui.mission.expand_hint')}</span>
      </div>

      <div className={styles.clock}>
        <span className={styles.pill}>{t('ui.mission.progress')}</span>
        <b>{formatClock(mission.seconds)}</b>
      </div>

      <div className={styles.objective}>
        <i />
        <span>{mission.briefing[0] || t('ui.mission.default_objective')}</span>
      </div>

      {mission.expanded && (
        <div className={styles.brief}>
          <div className={styles.briefHead}>
            <span>{t('ui.mission.briefing')}</span>
            <small>{t('ui.mission.steps')}</small>
          </div>
          <ol>
            {mission.briefing.map((step, index) => (
              <li key={index} className={index === 0 ? styles.current : undefined}>
                <span>{index + 1}</span>
                <p>{step}</p>
              </li>
            ))}
          </ol>
        </div>
      )}
    </aside>
  );
}
