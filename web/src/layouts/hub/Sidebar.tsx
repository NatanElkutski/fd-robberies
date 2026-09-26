import { ChatPanel } from '../../features/chat';
import { CrewPanel } from '../../features/crew';
import { ProfileCard } from '../../features/profile';
import styles from './Sidebar.module.css';

export function Sidebar() {
  return (
    <aside className={styles.sidebar}>
      <ProfileCard />
      <CrewPanel />
      <ChatPanel />
    </aside>
  );
}
