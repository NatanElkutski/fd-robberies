import { useEffect, useState } from 'react';
import { Modal } from '../../../components/Modal';
import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import { cancelSafe, submitCode } from '../api';
import styles from './SafeKeypad.module.css';

const CODE_LENGTH = 3;
const DIGITS = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];

/** Store rear-safe keypad with the hint note. */
export function SafeKeypad() {
  const t = useLocale();
  const { safe } = useStore();
  const dispatch = useDispatch();
  const [digits, setDigits] = useState('');

  useEffect(() => {
    if (safe.open) setDigits('');
  }, [safe.open, safe.storeId]);

  if (!safe.open || safe.storeId === null) return null;
  const storeId = safe.storeId;

  const press = (digit: string) => setDigits((current) => (current.length < CODE_LENGTH ? current + digit : current));

  const submit = () => {
    if (digits.length !== CODE_LENGTH) return;
    dispatch({ type: 'safeClose' });
    void submitCode(storeId, digits);
  };

  const cancel = () => {
    dispatch({ type: 'safeClose' });
    void cancelSafe();
  };

  const display = Array.from({ length: CODE_LENGTH }, (_, index) => digits[index] ?? '_').join(' ');

  return (
    <Modal>
      <div className={styles.scene}>
        <div className={styles.door}>
          <div className={styles.panel}>
            <span className={styles.brand}>{t('ui.safe.brand')}</span>
            <h2>{safe.label || t('ui.safe.title')}</h2>
            <div className={styles.display}>{display}</div>
            <div className={styles.keys}>
              {DIGITS.map((digit) => (
                <button key={digit} type="button" onClick={() => press(digit)}>
                  {digit}
                </button>
              ))}
              <button type="button" className={styles.clear} onClick={() => setDigits((current) => current.slice(0, -1))}>
                ⌫
              </button>
              <button type="button" onClick={() => press('0')}>
                0
              </button>
              <button type="button" className={styles.confirm} onClick={submit}>
                {t('ui.safe.confirm')}
              </button>
            </div>
            <button type="button" className={styles.cancel} onClick={cancel}>
              {t('ui.common.cancel')}
            </button>
          </div>
          <div className={styles.note}>
            <b>{t('ui.safe.hint_title')}</b>
            <p>{safe.hint}</p>
            <small>{t('ui.safe.hint_footer')}</small>
          </div>
        </div>
      </div>
    </Modal>
  );
}
