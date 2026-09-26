import { fetchNui } from '../../utils/fetchNui';

export const startHeist = (id: string) => fetchNui('start', { id });
