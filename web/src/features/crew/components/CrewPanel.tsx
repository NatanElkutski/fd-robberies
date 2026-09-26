import { useState } from 'react';
import { useLocale } from '../../../providers/LocaleProvider';
import { useStore } from '../../../store/StoreProvider';
import { acceptInvite, invitePlayer, leaveCrew, refreshNearby } from '../api';
import styles from './CrewPanel.module.css';

/** Sidebar crew block: members, invite by server id, nearby players, pending invites, leave. */
export function CrewPanel() {
  const t = useLocale();
  const { data, nearby } = useStore();
  const [inviteId, setInviteId] = useState('');
  const crew = data?.crew ?? { members: [], invites: [] };

  const sendInvite = () => {
    const id = Number(inviteId);
    if (id) void invitePlayer(id);
  };

  return (
    <section className={styles.section}>
      <h3>
        <i />
        {t('ui.crew.title')}
      </h3>

      <div>
        {crew.members.length === 0 && <p className={styles.muted}>{t('ui.crew.empty')}</p>}
        {crew.members.map((member) => (
          <div key={member.id} className={styles.row}>
            <span>
              {member.leader ? '👑' : '👤'} {member.name}
            </span>
            <b>ID {member.id}</b>
          </div>
        ))}
      </div>

      <div className={styles.inviteLine}>
        <input type="number" placeholder={t('ui.crew.server_id')} value={inviteId} onChange={(event) => setInviteId(event.target.value)} />
        <button type="button" onClick={sendInvite}>
          ＋
        </button>
      </div>

      <button type="button" className={styles.ghost} onClick={() => void refreshNearby()}>
        {t('ui.crew.find_nearby')}
      </button>

      <div>
        {nearby.map((player) => (
          <div key={player.id} className={styles.row}>
            <span>{player.name}</span>
            <button type="button" onClick={() => void invitePlayer(player.id)}>
              ＋
            </button>
          </div>
        ))}
      </div>

      <div>
        {crew.invites.map((invite) => (
          <div key={invite.id} className={styles.row}>
            <span>{invite.name}</span>
            <button type="button" onClick={() => void acceptInvite(invite.id)}>
              {t('ui.crew.accept')}
            </button>
          </div>
        ))}
      </div>

      <button type="button" className={styles.ghost} onClick={() => void leaveCrew()}>
        {t('ui.crew.leave')}
      </button>
    </section>
  );
}
