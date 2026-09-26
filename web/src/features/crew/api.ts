import { fetchNui } from '../../utils/fetchNui';

export const invitePlayer = (id: number) => fetchNui('crewInvite', { id });
export const acceptInvite = (id: number) => fetchNui('crewAccept', { id });
export const leaveCrew = () => fetchNui('crewLeave');
export const refreshNearby = () => fetchNui('refreshNearby');
