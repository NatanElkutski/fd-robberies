import { useStore } from '../../../store/StoreProvider';
import styles from './WorldPrompt.module.css';

/**
 * Floating "[E] ..." instruction pinned to a world position (Lua projects it to screen coords
 * every frame). Replaces GTA's native 3D text, which can't draw Hebrew.
 */
export function WorldPrompt() {
  const { worldPrompt } = useStore();
  if (!worldPrompt.show || !worldPrompt.text) return null;

  return (
    <div className={styles.anchor} style={{ left: `${worldPrompt.x * 100}%`, top: `${worldPrompt.y * 100}%` }}>
      <div className={styles.prompt}>
        {worldPrompt.key && <kbd className={styles.key}>{worldPrompt.key}</kbd>}
        <span className={styles.text}>{worldPrompt.text}</span>
      </div>
      <span className={styles.pointer} />
    </div>
  );
}
