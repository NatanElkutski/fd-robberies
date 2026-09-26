import { SectionTitle } from '../../components/SectionTitle';
import { Cart, ShopGrid } from '../../features/shop';
import { useLocale } from '../../providers/LocaleProvider';

export function ShopPage() {
  const t = useLocale();
  return (
    <>
      <SectionTitle title={t('ui.shop.title')} subtitle={t('ui.shop.subtitle')} />
      <ShopGrid />
      <Cart />
    </>
  );
}
