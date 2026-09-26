import type { ReactNode } from 'react';
import styles from './SectionTitle.module.css';

/** Page heading with the orange diamond, subtitle and an optional control on the far side. */
export function SectionTitle({ title, subtitle, children }: { title: string; subtitle: string; children?: ReactNode }) {
  return (
    <div className={styles.row}>
      <div className={styles.heading}>
        <span className={styles.diamond} />
        <h2>{title}</h2>
        <small>{subtitle}</small>
      </div>
      {children}
    </div>
  );
}
