import { useEffect, useState } from 'react';
import { getProviders, ProviderApplication } from '../api/admin';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate, ProviderActions } from './providerHelpers';

export function ProvidersPage() {
  const [items, setItems] = useState<ProviderApplication[]>([]);
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const result = await getProviders({ search, limit: 50 });
      setItems(result.items);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الموردين.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <section className="page-stack">
      <div className="page-heading">
        <div>
          <p>إدارة الموردين</p>
          <h2>كل ملفات الموردين وحالة الظهور العام</h2>
        </div>
      </div>
      <div className="filters">
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter') load();
          }}
          placeholder="بحث باسم المورد أو الهاتف"
        />
        <button className="button ghost" onClick={load}>
          بحث
        </button>
      </div>

      {items.length === 0 ? (
        <EmptyState title="لا يوجد موردون" message="لم يتم إنشاء ملفات موردين بعد." />
      ) : (
        <DataTable
          columns={[
            'اسم النشاط',
            'المدينة',
            'الفئة',
            'الخدمات',
            'الباقات',
            'العروض',
            'الحالة',
            'آخر تحديث',
            'إجراءات',
          ]}
        >
          {items.map((provider) => (
            <tr key={provider.id}>
              <td>{provider.businessName}</td>
              <td>{provider.city?.nameAr ?? 'غير محدد'}</td>
              <td>{provider.primaryCategory?.nameAr ?? 'غير محدد'}</td>
              <td>{provider.servicesCount}</td>
              <td>{provider.packagesCount}</td>
              <td>{provider.quoteRequestsCount}</td>
              <td>
                <StatusBadge status={provider.status} />
              </td>
              <td>{formatDate(provider.updatedAt)}</td>
              <td>
                <ProviderActions
                  provider={provider}
                  detailsPath={`/providers/${provider.id}`}
                  onChanged={load}
                />
              </td>
            </tr>
          ))}
        </DataTable>
      )}
    </section>
  );
}
