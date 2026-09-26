import type { PaymentMethod } from '../../types/protocol';
import { fetchNui } from '../../utils/fetchNui';

export const buyItem = (item: string, paymentMethod: PaymentMethod) => fetchNui('buyItem', { item, paymentMethod });
