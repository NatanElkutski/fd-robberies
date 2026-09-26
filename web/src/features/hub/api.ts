import { fetchNui } from '../../utils/fetchNui';

/** Releases NUI focus on the Lua side. */
export const closeUi = () => fetchNui('close');
