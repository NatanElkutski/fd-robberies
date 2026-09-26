import { Modal } from '../../../components/Modal';
import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import type { AtmMethod } from '../../../types/protocol';
import { cancelAtm, chooseMethod } from '../api';
import styles from './AtmMenu.module.css';

const METHODS: AtmMethod[] = ['rope', 'explosive', 'drill'];

/** Breach-method picker shown after ALT on an ATM. */
export function AtmMenu() {
  const t = useLocale();
  const { atmMenuOpen } = useStore();
  const dispatch = useDispatch();
  if (!atmMenuOpen) return null;

  const choose = (method: AtmMethod) => {
    dispatch({ type: 'atmMenu', show: false });
    void chooseMethod(method);
  };

  const cancel = () => {
    dispatch({ type: 'atmMenu', show: false });
    void cancelAtm();
  };

  return (
    <Modal>
      <div className={styles.box}>
        <span className={styles.kicker}>{t('ui.atm.kicker')}</span>
        <h2>{t('ui.atm.title')}</h2>
        <div className={styles.choices}>
          {METHODS.map((method) => (
            <button key={method} type="button" onClick={() => choose(method)}>
              <b>{t(`ui.atm.${method}`)}</b>
              <small>{t(`ui.atm.${method}_hint`)}</small>
            </button>
          ))}
        </div>
        <button type="button" className={styles.cancel} onClick={cancel}>
          {t('ui.common.cancel')}
        </button>
      </div>
    </Modal>
  );
}
