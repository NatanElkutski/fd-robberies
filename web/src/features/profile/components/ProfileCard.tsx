import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import { avatarImage } from '../../../utils/assets';
import styles from './ProfileCard.module.css';

/** Sidebar identity block: avatar, criminal name, level and XP bar. */
export function ProfileCard() {
  const t = useLocale();
  const { data } = useStore();
  const dispatch = useDispatch();
  if (!data) return null;

  const { progress, xpPerLevel } = data;
  const face = progress.criminal_avatar || 'face01';
  const into = (progress.xp || 0) % xpPerLevel;

  return (
    <section className={styles.identity}>
      <div className={styles.head}>
        <div className={styles.avatar} style={{ backgroundImage: `url('${avatarImage(face)}')` }} />
        <small>{t('ui.profile.identity')}</small>
        <b>{progress.criminal_name || t('ui.profile.unknown')}</b>
        <button type="button" className={styles.edit} onClick={() => dispatch({ type: 'profileOpen', face })}>
          {t('ui.profile.edit')}
        </button>
      </div>
      <div className={styles.levelRow}>
        <span>
          ✦ {t('ui.common.level')} <i>{progress.level || 1}</i>
        </span>
        <span>
          {into} / {xpPerLevel} XP
        </span>
      </div>
      <div className={styles.xp}>
        <em style={{ width: `${Math.min(100, (into / xpPerLevel) * 100)}%` }} />
      </div>
    </section>
  );
}
