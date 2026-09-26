import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import type { PaymentMethod } from '../../../types/protocol';
import { formatMoney } from '../../../utils/format';
import { buyItem } from '../api';
import styles from './Cart.module.css';

/** Cart with totals; checkout sends one purchase per unit (the server prices each). */
export function Cart() {
  const t = useLocale();
  const { cart, shop } = useStore();
  const dispatch = useDispatch();
  const total = cart.reduce((sum, line) => sum + line.price * line.qty, 0);

  const checkout = async (method: PaymentMethod) => {
    for (const line of cart) {
      for (let unit = 0; unit < line.qty; unit++) {
        await buyItem(line.name, method);
      }
    }
    dispatch({ type: 'cartClear' });
  };

  return (
    <aside className={styles.cart}>
      <h2>{t('ui.shop.cart')}</h2>
      <div className={styles.lines}>
        {cart.length === 0 && <p className={styles.muted}>{t('ui.shop.cart_empty')}</p>}
        {cart.map((line, index) => (
          <div key={line.name} className={styles.line}>
            <span>
              {t(`shop.items.${line.name}.label`)} ×{line.qty}
            </span>
            <b>${formatMoney(line.price * line.qty)}</b>
            <button type="button" onClick={() => dispatch({ type: 'cartRemove', index })}>
              ×
            </button>
          </div>
        ))}
      </div>
      <div className={styles.total}>
        <span>{t('ui.shop.total')}</span>
        <b>${formatMoney(total)}</b>
      </div>
      {shop.allowCash && (
        <button type="button" onClick={() => void checkout('cash')}>
          {t('ui.shop.pay_cash')}
        </button>
      )}
      {shop.allowBank && (
        <button type="button" className={styles.bank} onClick={() => void checkout('bank')}>
          {t('ui.shop.pay_bank')}
        </button>
      )}
    </aside>
  );
}
