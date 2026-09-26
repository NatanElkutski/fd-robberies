import { useEffect, useRef, useState } from 'react';
import { useLocale } from '../../../providers/LocaleProvider';
import { useStore } from '../../../store/StoreProvider';
import { invitePlayer } from '../../crew';
import { requestChatFocus, sendMessage } from '../api';
import styles from './ChatPanel.module.css';

const MAX_LENGTH = 120;

/** Underground lobby chat. Text is rendered as text (never HTML). */
export function ChatPanel() {
  const t = useLocale();
  const { data } = useStore();
  const [draft, setDraft] = useState('');
  const listRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const messages = data?.chat ?? [];

  useEffect(() => {
    const list = listRef.current;
    if (list) list.scrollTop = list.scrollHeight;
  }, [messages.length]);

  const send = async () => {
    const text = draft.trim();
    if (!text) return;
    setDraft('');
    await sendMessage(text);
    inputRef.current?.focus();
  };

  return (
    <section className={styles.chat}>
      <h3>
        <i />
        {t('ui.chat.title')}
      </h3>

      <div ref={listRef} className={styles.messages}>
        {messages.map((message, index) => (
          <div key={`${message.time}-${message.id}-${index}`} className={styles.message}>
            <div>
              <b>{message.name}</b>
              <small>{t('ui.chat.meta', message.id)}</small>
              <p>{message.text}</p>
            </div>
            <button type="button" title={t('ui.chat.invite')} onClick={() => void invitePlayer(message.id)}>
              ＋
            </button>
          </div>
        ))}
      </div>

      <div className={styles.send}>
        <input
          ref={inputRef}
          maxLength={MAX_LENGTH}
          value={draft}
          placeholder={t('ui.chat.placeholder')}
          onChange={(event) => setDraft(event.target.value)}
          onFocus={() => void requestChatFocus()}
          onMouseDown={(event) => {
            event.stopPropagation();
            void requestChatFocus();
          }}
          onKeyDown={(event) => {
            event.stopPropagation();
            if (event.key === 'Enter') {
              event.preventDefault();
              void send();
            }
          }}
        />
        <button type="button" onClick={() => void send()}>
          ➤
        </button>
      </div>
    </section>
  );
}
