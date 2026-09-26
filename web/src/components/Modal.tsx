import type { ReactNode } from 'react';
import styles from './Modal.module.css';

/** Full-screen dimmed overlay that centers its content. */
export function Modal({ children, zIndex = 50 }: { children: ReactNode; zIndex?: number }) {
  return (
    <div className={styles.overlay} style={{ zIndex }}>
      {children}
    </div>
  );
}
