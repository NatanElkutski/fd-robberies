import { RefHeading } from '../../../components/RefHeading';
import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import { shopImage } from '../../../utils/assets';
import { formatMoney } from '../../../utils/format';
import styles from './HomeShopStrip.module.css';

const HOME_ITEMS = 8;

/** Home-page teaser of the black market; any tile opens the shop tab. */
export function HomeShopStrip() {
  const t = useLocale();
  const { shop } = useStore();
  const dispatch = useDispatch();

  return (
    <section className={styles.section}>
      <RefHeading icon="🎮" title={t('ui.home_shop.title')} subtitle={t('ui.home_shop.subtitle')} />
      <div className={styles.strip}>
        {shop.items.slice(0, HOME_ITEMS).map((item) => (
          <button key={item.name} type="button" className={styles.item} onClick={() => dispatch({ type: 'setTab', tab: 'shop' })}>
            <span className={styles.pic} style={{ backgroundImage: `url('${shopImage(item.name)}')` }} />
            <b>{t(`shop.items.${item.name}.label`)}</b>
            <strong>${formatMoney(item.price)}</strong>
          </button>
        ))}
      </div>
    </section>
  );
}
