import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import { shopImage } from '../../../utils/assets';
import { formatMoney } from '../../../utils/format';
import styles from './ShopGrid.module.css';

/** Equipment tiles; clicking adds one to the cart. */
export function ShopGrid() {
  const t = useLocale();
  const { shop } = useStore();
  const dispatch = useDispatch();

  return (
    <div className={styles.grid}>
      {shop.items.map((item) => (
        <article key={item.name} className={styles.item} onClick={() => dispatch({ type: 'cartAdd', item })}>
          <div className={styles.photo} style={{ backgroundImage: `url('${shopImage(item.name)}')` }} />
          <div className={styles.info}>
            <b>{t(`shop.items.${item.name}.label`)}</b>
            <small>{t(`shop.items.${item.name}.description`)}</small>
          </div>
          <strong className={styles.price}>${formatMoney(item.price)}</strong>
        </article>
      ))}
    </div>
  );
}
