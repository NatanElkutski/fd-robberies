import { useEffect, useRef, useState } from 'react';
import { Modal } from '../../../components/Modal';
import { useLocale } from '../../../providers/LocaleProvider';
import { useDispatch, useStore } from '../../../store/StoreProvider';
import { AVATAR_IDS, avatarImage } from '../../../utils/assets';
import { saveProfile } from '../api';
import styles from './ProfileModal.module.css';

const MIN_NAME = 3;
const MAX_NAME = 24;

/** Criminal identity editor: name + face. */
export function ProfileModal() {
  const t = useLocale();
  const { profile, data } = useStore();
  const dispatch = useDispatch();
  const [name, setName] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (profile.open) {
      setName(data?.progress.criminal_name ?? '');
      inputRef.current?.focus();
    }
  }, [profile.open, data?.progress.criminal_name]);

  if (!profile.open) return null;

  const save = async () => {
    const trimmed = name.trim();
    if (trimmed.length < MIN_NAME) return;
    await saveProfile(trimmed, profile.face);
    dispatch({ type: 'profileSaved', name: trimmed, face: profile.face });
  };

  return (
    <Modal>
      <div className={styles.box}>
        <div className={styles.title}>
          <span>{t('ui.profile.kicker')}</span>
          <h2>{t('ui.profile.title')}</h2>
          <p>{t('ui.profile.hint')}</p>
        </div>

        <label htmlFor="criminalName">{t('ui.profile.name_label')}</label>
        <input
          id="criminalName"
          ref={inputRef}
          className={styles.input}
          maxLength={MAX_NAME}
          value={name}
          placeholder={t('ui.profile.name_placeholder')}
          onChange={(event) => setName(event.target.value)}
        />

        <label>{t('ui.profile.face_label')}</label>
        <div className={styles.faces}>
          {AVATAR_IDS.map((face) => (
            <button
              key={face}
              type="button"
              data-face={face}
              className={`${styles.face} ${face === profile.face ? styles.selected : ''}`}
              style={{ backgroundImage: `url('${avatarImage(face)}')` }}
              onClick={() => dispatch({ type: 'profileFace', face })}
            />
          ))}
        </div>

        <div className={styles.actions}>
          <button type="button" onClick={() => dispatch({ type: 'profileClose' })}>
            {t('ui.common.cancel')}
          </button>
          <button type="button" className={styles.save} onClick={save}>
            {t('ui.profile.save')}
          </button>
        </div>
      </div>
    </Modal>
  );
}
