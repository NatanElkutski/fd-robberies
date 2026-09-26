import { fetchNui } from '../../utils/fetchNui';

export const saveProfile = (name: string, avatar: string) => fetchNui('saveCriminalProfile', { name, avatar });
