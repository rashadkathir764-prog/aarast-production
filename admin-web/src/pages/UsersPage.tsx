import { useEffect, useState } from 'react';
import { getUsers } from '../api/admin';
import { AdminUser } from '../api/auth';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate } from './providerHelpers';

type UserRow = AdminUser & {
  provider?: {
    id: string;
    businessName: string;
    status: string;
  } | null;
};

export function UsersPage() {
  const [items, setItems] = useState<UserRow[]>([]);
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const result = await getUsers({ search, limit: 50 });
      setItems(result.items as UserRow[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل المستخدمين.');
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
          <p>المستخدمون</p>
          <h2>عرض حسابات المستخدمين بدون أي حقول حساسة</h2>
        </div>
      </div>
      <div className="filters">
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter') load();
          }}
          placeholder="بحث بالاسم أو الهاتف"
        />
        <button className="button ghost" onClick={load}>
          بحث
        </button>
      </div>
      {items.length === 0 ? (
        <EmptyState title="لا يوجد مستخدمون" message="لا توجد حسابات مطابقة." />
      ) : (
        <DataTable
          columns={[
            'الاسم',
            'الهاتف',
            'البريد',
            'الدور',
            'الحالة',
            'المورد',
            'تاريخ الإنشاء',
          ]}
        >
          {items.map((user) => (
            <tr key={user.id}>
              <td>{user.name}</td>
              <td dir="ltr">{user.phone ?? 'غير محدد'}</td>
              <td>{user.email ?? 'غير محدد'}</td>
              <td>{user.role}</td>
              <td>{user.status}</td>
              <td>
                {user.provider ? (
                  <span className="provider-cell">
                    {user.provider.businessName}
                    <StatusBadge status={user.provider.status} />
                  </span>
                ) : (
                  'لا يوجد'
                )}
              </td>
              <td>{formatDate(user.createdAt)}</td>
            </tr>
          ))}
        </DataTable>
      )}
    </section>
  );
}
