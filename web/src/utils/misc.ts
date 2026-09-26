/** True when running in a normal browser (npm run dev) instead of the FiveM NUI. */
export const isEnvBrowser = (): boolean => !(window as { invokeNative?: unknown }).invokeNative;

/** Resource name used for NUI callback URLs. */
export const resourceName = (): string =>
  (window as { GetParentResourceName?: () => string }).GetParentResourceName?.() ?? 'fd-robberies';
