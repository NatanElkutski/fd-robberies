import styles from './RefHeading.module.css';

/** Emoji + title + subtitle heading used for the home-page strips. */
export function RefHeading({ icon, title, subtitle }: { icon: string; title: string; subtitle: string }) {
  return (
    <div className={styles.heading}>
      <span className={styles.icon}>{icon}</span>
      <div>
        <h2>{title}</h2>
        <small>{subtitle}</small>
      </div>
    </div>
  );
}
