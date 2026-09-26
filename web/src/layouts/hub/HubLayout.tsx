import { useStore } from '../../store/StoreProvider';
import { Header } from './Header';
import { HeistsPage } from './HeistsPage';
import styles from './HubLayout.module.css';
import { ShopPage } from './ShopPage';
import { Sidebar } from './Sidebar';

/** The focused robbery menu: header, sidebar (profile/crew/chat) and the active tab. */
export function HubLayout({ onClose }: { onClose: () => void }) {
  const { hubOpen, tab } = useStore();
  if (!hubOpen) return null;

  return (
    <div className={styles.overlay}>
      <div className={styles.shell}>
        <Header onClose={onClose} />
        <div className={styles.workspace}>
          <Sidebar />
          <main className={styles.main}>{tab === 'heists' ? <HeistsPage /> : <ShopPage />}</main>
        </div>
      </div>
    </div>
  );
}
