import { fetchNui } from '../../utils/fetchNui';

/** Releases NUI focus on the Lua side. */
export const closeUi = () => fetchNui('close');

/** Tells Lua the page is mounted; Lua refuses to take mouse focus before this. */
export const markReady = () => fetchNui('ready');

/** Reports a UI crash; Lua logs it and releases focus. */
export const reportUiError = (message: string) => fetchNui('uiError', { message });
