import { AtmMenu } from './features/atm';
import { closeUi } from './features/hub';
import { ProfileModal } from './features/profile';
import { SafeKeypad } from './features/safe';
import { useExitListener } from './hooks/useExitListener';
import { HubLayout } from './layouts/hub/HubLayout';
import { HudLayout } from './layouts/hud/HudLayout';
import { useDispatch } from './store/StoreProvider';
import { useNuiSync } from './store/useNuiSync';

export function App() {
  const dispatch = useDispatch();
  useNuiSync();

  const closeAll = () => {
    dispatch({ type: 'closeAll' });
    void closeUi();
  };
  useExitListener(closeAll);

  return (
    <>
      <HudLayout />
      <HubLayout onClose={closeAll} />
      <ProfileModal />
      <AtmMenu />
      <SafeKeypad />
    </>
  );
}
