import { useLocale } from '../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../store/StoreProvider';
import type { HubTab } from '../../store/state';
import { avatarImage } from '../../utils/assets';
import styles from './Header.module.css';

const TABS: HubTab[] = ['heists', 'shop'];

export function Header({ onClose }: { onClose: () => void }) {
  const t = useLocale();
  const { tab, data } = useStore();
  const dispatch = useDispatch();
  const progress = data?.progress;

  return (
    <header className={styles.header}>
      <div className={styles.brand}>
        <div className={styles.logo}>
          <span>F</span>
          <span>D</span>
        </div>
        <div className={styles.brandCopy}>
          <b>FIVE DEV</b>
          <small>CRIMINAL NETWORK</small>
        </div>
      </div>

      <nav className={styles.tabs}>
        {TABS.map((id) => (
          <button key={id} type="button" className={id === tab ? styles.active : undefined} onClick={() => dispatch({ type: 'setTab', tab: id })}>
            {t(`ui.tabs.${id}`)}
          </button>
        ))}
      </nav>

      <div className={styles.account}>
        <div className={styles.miniFace} style={{ backgroundImage: `url('${avatarImage(progress?.criminal_avatar || 'face01')}')` }} />
        <span className={styles.name}>{progress?.criminal_name || t('ui.profile.unknown')}</span>
        <b className={styles.level}>
          {t('ui.common.level')} <i>{progress?.level ?? 1}</i>
        </b>
        <button type="button" className={styles.close} aria-label={t('ui.common.close')} onClick={onClose}>
          ✕
        </button>
      </div>
    </header>
  );
}
