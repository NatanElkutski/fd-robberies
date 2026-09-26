import { fetchNui } from '../../utils/fetchNui';

export const submitCode = (storeId: number, code: string) => fetchNui('safeSubmit', { storeId, code });
export const cancelSafe = () => fetchNui('safeCancel');
