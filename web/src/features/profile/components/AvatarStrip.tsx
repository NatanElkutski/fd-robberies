import { RefHeading } from '../../../components/RefHeading';
import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import { AVATAR_IDS, avatarImage } from '../../../utils/assets';
import styles from './AvatarStrip.module.css';

const HOME_AVATARS = AVATAR_IDS.slice(0, 9);

/** Home-page avatar row; clicking a face opens the identity editor with it preselected. */
export function AvatarStrip() {
  const t = useLocale();
  const { data } = useStore();
  const dispatch = useDispatch();
  const current = data?.progress.criminal_avatar || 'face01';

  return (
    <section className={styles.section}>
      <RefHeading icon="🔫" title={t('ui.avatars.title')} subtitle={t('ui.avatars.subtitle')} />
      <div className={styles.strip}>
        {HOME_AVATARS.map((face) => (
          <button
            key={face}
            type="button"
            title={t('ui.avatars.pick')}
            className={`${styles.avatar} ${face === current ? styles.selected : ''}`}
            style={{ backgroundImage: `url('${avatarImage(face)}')` }}
            onClick={() => dispatch({ type: 'profileOpen', face })}
          />
        ))}
      </div>
    </section>
  );
}
