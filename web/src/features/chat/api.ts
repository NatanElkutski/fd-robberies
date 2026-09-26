import { fetchNui } from '../../utils/fetchNui';

export const sendMessage = (text: string) => fetchNui('lobbyMessage', { text });
export const requestChatFocus = () => fetchNui('chatFocus');
