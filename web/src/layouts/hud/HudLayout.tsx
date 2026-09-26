import { MissionHud } from '../../features/mission';
import { WorldPrompt } from '../../features/prompt';

/** Non-focused overlays shown while playing. */
export function HudLayout() {
  return (
    <>
      <MissionHud />
      <WorldPrompt />
    </>
  );
}
