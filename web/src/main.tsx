import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { ErrorBoundary } from './components/ErrorBoundary';
import { reportUiError } from './features/hub';
import { LocaleProvider } from './providers/LocaleProvider';
import { StoreProvider } from './store/StoreProvider';
import './theme/tokens.css';
import './theme/base.css';
import { debugData } from './utils/debugData';
import { isEnvBrowser } from './utils/misc';

if (isEnvBrowser()) {
  debugData();
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary onError={(error) => void reportUiError(error.message)}>
      <StoreProvider>
        <LocaleProvider>
          <App />
        </LocaleProvider>
      </StoreProvider>
    </ErrorBoundary>
  </StrictMode>,
);
