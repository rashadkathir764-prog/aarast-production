// «الخدمات»: drawn in the designs' sidebar but without a page of its own
// (D56), so it uses the desk kit the designed pages use. The providers'
// services with their section, city and price; a service is stopped or run
// again after a confirmation that says what it does, and the team adds a
// service to a provider (the listed-provider form on a05 sends them here).
// Featuring is the provider's placement on a17 only (B-43).
import { type FormEvent, useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Plus } from 'lucide-react';
import {
  type City,
  createService,
  getCategories,
  getCities,
  getServices,
  type ProviderCategory,
  type ProviderService,
  updateService,
} from './api';
import { getProviders, type ProviderApplication } from '../providers/api';
import { AdminPermission, Can } from '../auth/api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  SoftAction,
  Tag,
  TwoLine,
  grouped,
  phoneSpaced,
} from '../../design_system/Desk';
import { DeskModal } from '../../design_system/DeskModal';

type Page = {
  items: ProviderService[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

type Filters = { search: string; status: string; cityId: string; categoryId: string };

const NO_FILTERS: Filters = { search: '', status: '', cityId: '', categoryId: '' };

function price(service: ProviderService) {
  if (!service.basePrice) return 'حسب الطلب';
  const amount = grouped(service.basePrice);
  return service.currency && service.currency !== 'YER' ? `${amount} ${service.currency}` : amount;
}

export function ServicesPage() {
  const [filters, setFilters] = useState<Filters>(NO_FILTERS);
  const [searchDraft, setSearchDraft] = useState('');
  const [page, setPage] = useState(1);
  const [attempt, setAttempt] = useState(0);
  const [result, setResult] = useState<Page | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [cities, setCities] = useState<City[]>([]);
  const [categories, setCategories] = useState<ProviderCategory[]>([]);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    // Only the answer to the latest filters and page is shown.
    let current = true;
    setError(null);
    const { search, status, cityId, categoryId } = filters;
    getServices({ search, status, cityId, categoryId, page, limit: 20 }).then(
      (next) => {
        if (!current) return;
        if (page > next.totalPages && next.totalPages > 0) setPage(next.totalPages);
        else setResult(next);
      },
      (value: unknown) => {
        if (current) setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الخدمات.');
      },
    );
    return () => {
      current = false;
    };
  }, [filters, page, attempt]);

  // The filter lists; the table works without them.
  useEffect(() => {
    getCities().then(setCities, () => setCities([]));
    getCategories().then(setCategories, () => setCategories([]));
  }, []);

  const reload = useCallback(() => setAttempt((value) => value + 1), []);

  function filter(next: Partial<Filters>) {
    setFilters((current) => ({ ...current, ...next }));
    setPage(1);
  }

  function submitSearch(event: FormEvent) {
    event.preventDefault();
    filter({ search: searchDraft.trim() });
  }

  const filtered = Object.values(filters).some(Boolean);

  return (
    <section>
      <DeskHeader
        title="الخدمات"
        sub={result ? `${grouped(result.total)} خدمة${filtered ? ' تطابق البحث' : ''}` : undefined}
        actions={
          <Can permission={AdminPermission.SERVICES_WRITE}>
            <DeskButton icon={Plus} onClick={() => setAdding(true)}>
              أضف خدمة لمزود
            </DeskButton>
          </Can>
        }
      />
      <Panel>
        <form className="desk-row" onSubmit={submitSearch} role="search" style={{ alignItems: 'flex-end' }}>
          <label className="desk-field">
            ابحث بالخدمة أو المزود
            <input value={searchDraft} onChange={(event) => setSearchDraft(event.target.value)} />
          </label>
          <label className="desk-field">
            الحالة
            <select value={filters.status} onChange={(event) => filter({ status: event.target.value })}>
              <option value="">الكل</option>
              <option value="ACTIVE">شغّالة</option>
              <option value="DISABLED">موقوفة</option>
            </select>
          </label>
          <label className="desk-field">
            المدينة
            <select value={filters.cityId} onChange={(event) => filter({ cityId: event.target.value })}>
              <option value="">كل المدن</option>
              {cities.map((city) => (
                <option key={city.id} value={city.id}>
                  {city.nameAr}
                </option>
              ))}
            </select>
          </label>
          <label className="desk-field">
            القسم
            <select value={filters.categoryId} onChange={(event) => filter({ categoryId: event.target.value })}>
              <option value="">كل الأقسام</option>
              {categories.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.nameAr}
                </option>
              ))}
            </select>
          </label>
          <DeskButton type="submit">ابحث</DeskButton>
        </form>
      </Panel>
      <div className="desk-gap" />
      {error ? <DeskRetry message={error} onRetry={reload} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل الخدمات…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>{filtered ? 'ما فيه خدمة تطابق البحث.' : 'ما فيه خدمات بعد.'}</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <DeskTable
            caption="الخدمات"
            columns={[
              { label: 'الخدمة', flex: 3 },
              { label: 'المزود', flex: 3 },
              { label: 'القسم', flex: 2 },
              { label: 'المدينة', flex: 2 },
              { label: 'السعر', flex: 2 },
              { label: 'الحالة', flex: 2 },
            ]}
            rows={result.items}
            rowKey={(service) => service.id}
            renderRow={(service) => [
              <TwoLine key="t" main={service.title} sub={service.description ?? undefined} />,
              service.provider ? (
                <span key="p" className="desk-two">
                  <Link to={`/providers/${service.provider.id}`}>
                    <strong>{service.provider.businessName}</strong>
                  </Link>
                  <small className="desk-num">{phoneSpaced(service.provider.phone)}</small>
                </span>
              ) : (
                <span key="p" className="desk-ink--muted">—</span>
              ),
              service.category?.nameAr ?? '—',
              service.city?.nameAr ?? service.provider?.city?.nameAr ?? '—',
              <span key="m" className="desk-num">{price(service)}</span>,
              <ServiceState key="s" service={service} onChanged={reload} />,
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

      <AddServiceWindow
        open={adding}
        categories={categories.filter((category) => category.isActive)}
        onClose={() => setAdding(false)}
        onAdded={() => {
          setAdding(false);
          reload();
        }}
      />
    </section>
  );
}

function ServiceState({ service, onChanged }: { service: ProviderService; onChanged: () => void }) {
  const running = service.isActive;
  return (
    <span className="desk-actions">
      {running ? <Tag tone="green">شغّالة</Tag> : <Tag tone="muted">موقوفة</Tag>}
      <Can permission={AdminPermission.SERVICES_WRITE}>
        <ConfirmDialog
          variant="desk"
          title={`${running ? 'إيقاف' : 'تشغيل'} «${service.title}»`}
          effects={
            running
              ? [
                  'ما تظهر للعرسان، ولا تنطلب عليها عروض جديدة.',
                  'لو كانت آخر خدمة شغّالة عند المزود، المزود نفسه ما يظهر للعرسان.',
                ]
              : ['ترجع تظهر للعرسان مع ملف المزود.']
          }
          confirmLabel={running ? 'أوقفها' : 'شغّلها'}
          confirmTone={running ? 'coral' : 'teal'}
          trigger={<SoftAction tone={running ? 'coral' : 'soft'}>{running ? 'أوقفها' : 'شغّلها'}</SoftAction>}
          onConfirm={async () => {
            await updateService(service.id, { isActive: !running });
            onChanged();
          }}
        />
      </Can>
    </span>
  );
}

type Draft = { categoryId: string; title: string; basePrice: string };

const EMPTY: Draft = { categoryId: '', title: '', basePrice: '' };

/** «أضف خدمة لمزود»: find the provider, then the section, name and price. */
function AddServiceWindow({
  open,
  categories,
  onClose,
  onAdded,
}: {
  open: boolean;
  categories: ProviderCategory[];
  onClose: () => void;
  onAdded: () => void;
}) {
  const [providerSearch, setProviderSearch] = useState('');
  const [providerSearchQuery, setProviderSearchQuery] = useState<string | null>(null);
  const [found, setFound] = useState<ProviderApplication[] | null>(null);
  const [provider, setProvider] = useState<ProviderApplication | null>(null);
  const [draft, setDraft] = useState<Draft>(EMPTY);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) {
      setProviderSearch('');
      setProviderSearchQuery(null);
      setFound(null);
      setProvider(null);
      setDraft(EMPTY);
      setError(null);
    }
  }, [open]);

  useEffect(() => {
    if (providerSearchQuery === null) return undefined;
    let current = true;
    setError(null);
    getProviders({ search: providerSearchQuery, page: 1, limit: 20 }).then(
      (page) => {
        if (current) setFound(page.items);
      },
      (value: unknown) => {
        if (current) setError(value instanceof Error ? value.message : 'ما قدرنا ندوّر على المزود.');
      },
    );
    return () => {
      current = false;
    };
  }, [providerSearchQuery]);

  function find(event: FormEvent) {
    event.preventDefault();
    setFound(null);
    setProviderSearchQuery(providerSearch.trim());
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!provider || !draft.categoryId || !draft.title.trim()) return;
    setSaving(true);
    setError(null);
    try {
      await createService({
        providerId: provider.id,
        categoryId: draft.categoryId,
        title: draft.title.trim(),
        basePrice: draft.basePrice.trim() || null,
        currency: 'YER',
        isActive: true,
      });
      onAdded();
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحفظ الخدمة.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <DeskModal title="أضف خدمة لمزود" open={open} onClose={onClose}>
      {provider ? (
        <form className="desk-form" onSubmit={submit}>
          <div className="desk-actions">
            <strong>{provider.businessName}</strong>
            <SoftAction onClick={() => setProvider(null)}>غيّر المزود</SoftAction>
          </div>
          <label className="desk-field">
            القسم
            <select
              value={draft.categoryId}
              onChange={(event) => setDraft({ ...draft, categoryId: event.target.value })}
              required
            >
              <option value="">اختر القسم</option>
              {categories.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.nameAr}
                </option>
              ))}
            </select>
          </label>
          <label className="desk-field">
            اسم الخدمة
            <input
              value={draft.title}
              onChange={(event) => setDraft({ ...draft, title: event.target.value })}
              required
            />
          </label>
          <label className="desk-field">
            السعر (اختياري)
            <input
              value={draft.basePrice}
              inputMode="decimal"
              dir="ltr"
              onChange={(event) => setDraft({ ...draft, basePrice: event.target.value })}
            />
          </label>
          {error ? <DeskNote tone="coral">{error}</DeskNote> : null}
          <div className="desk-dialog__actions">
            <DeskButton type="submit" disabled={saving || !draft.categoryId || !draft.title.trim()}>
              أضف الخدمة
            </DeskButton>
          </div>
        </form>
      ) : (
        <form className="desk-form" onSubmit={find}>
          <label className="desk-field">
            المزود
            <input
              value={providerSearch}
              placeholder="ابحث باسم النشاط أو الرقم"
              onChange={(event) => setProviderSearch(event.target.value)}
              required
            />
          </label>
          <div className="desk-dialog__actions">
            <DeskButton type="submit">ابحث</DeskButton>
          </div>
          {found && found.length === 0 ? <DeskNote>ما لقينا مزود بهذا الاسم أو الرقم.</DeskNote> : null}
          {found && found.length > 0 ? (
            <div className="desk-actions">
              {found.map((item) => (
                <SoftAction key={item.id} onClick={() => setProvider(item)}>
                  {item.businessName}
                </SoftAction>
              ))}
            </div>
          ) : null}
          {error ? <DeskNote tone="coral">{error}</DeskNote> : null}
        </form>
      )}
    </DeskModal>
  );
}
