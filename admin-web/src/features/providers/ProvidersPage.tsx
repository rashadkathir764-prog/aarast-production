// a05 «دليل المزودين»: the active and suspended providers with their marks. The
// bookings column waits for B-40 and «تقويم قديم» for B-25; the teams under
// the name left with D41. Adding a listed provider and importing a file open
// the existing forms in a window.
import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Upload } from 'lucide-react';
import {
  getProviders,
  type CityProjection,
  type ProviderApplication,
  type ProviderCategoryProjection,
} from './api';
import { AddListedProviderCard } from './AddListedProviderCard';
import { ImportProvidersCard } from './ImportProvidersCard';
import { ProviderStatusTag } from './providerHelpers';
import { AdminPermission, Can } from '../auth/api';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  Tag,
  TwoLine,
} from '../../design_system/Desk';
import { DeskModal } from '../../design_system/DeskModal';

// RA-AD-15: the directory lists the active and the suspended, so its count
// is theirs, not every status (pending and refused profiles live elsewhere).
type DirectoryCounts = { approvedProviders: number; suspendedProviders?: number };

type ProvidersPageProps = {
  getCities: () => Promise<CityProjection[]>;
  getCategories: () => Promise<ProviderCategoryProjection[]>;
  getStats: () => Promise<DirectoryCounts>;
};

type Page = {
  items: ProviderApplication[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

function rating(provider: ProviderApplication): string {
  if (!provider.ratingCount) return '—';
  return `${Number(provider.ratingAverage).toFixed(1)} · ${provider.ratingCount}`;
}

export function ProvidersPage({ getCities, getCategories, getStats }: ProvidersPageProps) {
  const navigate = useNavigate();
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page | null>(null);
  const [counts, setCounts] = useState<DirectoryCounts | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<'add' | 'import' | null>(null);
  const [cities, setCities] = useState<CityProjection[]>([]);
  const [categories, setCategories] = useState<ProviderCategoryProjection[]>([]);

  const load = useCallback(async () => {
    setError(null);
    try {
      // No status: the server answers with active and suspended providers.
      setResult(await getProviders({ page, limit: 20 }));
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الدليل.');
    }
  }, [page]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    getStats().then(setCounts, () => setCounts(null));
  }, [getStats]);

  async function open(next: 'add' | 'import') {
    setForm(next);
    if (cities.length === 0 || categories.length === 0) {
      try {
        const [nextCities, nextCategories] = await Promise.all([getCities(), getCategories()]);
        setCities(nextCities.filter((city) => city.isActive));
        setCategories(nextCategories.filter((category) => category.isActive));
      } catch (value) {
        setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل المدن والأقسام.');
      }
    }
  }

  // The window stays open so its own result line («أُضيف …») stays readable.
  async function changed() {
    await load();
    getStats().then(setCounts, () => undefined);
  }

  return (
    <section>
      <DeskHeader
        title="دليل المزودين"
        sub={
          counts
            ? `${counts.approvedProviders + (counts.suspendedProviders ?? 0)} مزود · ${counts.approvedProviders} نشط`
            : undefined
        }
        actions={
          <Can permission={AdminPermission.PROVIDERS_WRITE}>
            <DeskButton tone="soft" icon={Plus} onClick={() => void open('add')}>
              أضف مزود بلا حساب
            </DeskButton>
            <DeskButton tone="soft" icon={Upload} onClick={() => void open('import')}>
              استيراد ملف
            </DeskButton>
          </Can>
        }
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل الدليل…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه مزودين بعد.</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <DeskTable
            caption="دليل المزودين"
            columns={[
              { label: 'المزود', flex: 4 },
              { label: 'الحالة', flex: 2 },
              { label: 'المدينة', flex: 2 },
              { label: 'علامات', flex: 4 },
              { label: 'التقييم', flex: 2 },
            ]}
            rows={result.items}
            rowKey={(provider) => provider.id}
            onRowClick={(provider) => navigate(`/providers/${provider.id}`)}
            rowLabel={(provider) => `افتح ${provider.businessName}`}
            renderRow={(provider) => [
              <TwoLine
                key="p"
                main={provider.businessName}
                sub={provider.primaryCategory?.nameAr}
              />,
              <ProviderStatusTag key="s" status={provider.status} />,
              provider.city?.nameAr ?? '—',
              <span key="m" className="desk-tags">
                {provider.verifiedAt ? <Tag tone="green">موثّق</Tag> : null}
                {provider.isFeatured ? <Tag tone="saffron">مميز</Tag> : null}
                {provider.userId ? null : <Tag tone="muted">بلا حساب</Tag>}
              </span>,
              rating(provider),
            ]}
          />
          <DeskPager
            page={result.page}
            limit={result.limit}
            total={result.total}
            totalPages={result.totalPages}
            onPageChange={setPage}
          />
        </>
      ) : null}

      <DeskModal title="أضف مزود بلا حساب" open={form === 'add'} onClose={() => setForm(null)} wide>
        <AddListedProviderCard cities={cities} categories={categories} onCreated={changed} />
      </DeskModal>
      <DeskModal title="استيراد ملف" open={form === 'import'} onClose={() => setForm(null)} wide>
        <ImportProvidersCard cities={cities} categories={categories} onImported={changed} />
      </DeskModal>
    </section>
  );
}
