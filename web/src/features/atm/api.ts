import type { AtmMethod } from '../../types/protocol';
import { fetchNui } from '../../utils/fetchNui';

export const chooseMethod = (method: AtmMethod) => fetchNui('atmChoose', { method });
export const cancelAtm = () => fetchNui('atmCancel');
