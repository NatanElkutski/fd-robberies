import { SectionTitle } from '../../components/SectionTitle';
import { HeistGrid, HeistSearch } from '../../features/heists';
import { AvatarStrip } from '../../features/profile';
import { HomeShopStrip } from '../../features/shop';
import { useLocale } from '../../providers/LocaleProvider';

export function HeistsPage() {
  const t = useLocale();
  return (
    <>
      <SectionTitle title={t('ui.heists.title')} subtitle={t('ui.heists.subtitle')}>
        <HeistSearch />
      </SectionTitle>
      <HeistGrid />
      <AvatarStrip />
      <HomeShopStrip />
    </>
  );
}
