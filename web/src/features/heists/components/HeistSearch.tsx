import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import styles from './HeistSearch.module.css';

export function HeistSearch() {
  const t = useLocale();
  const { search } = useStore();
  const dispatch = useDispatch();

  return (
    <input
      className={styles.search}
      value={search}
      placeholder={t('ui.heists.search')}
      onChange={(event) => dispatch({ type: 'search', value: event.target.value })}
    />
  );
}
