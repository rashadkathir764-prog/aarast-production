import { useEffect, useState } from 'react';
import {
  AdminAuditLog,
  AdminAuditPhase,
  getAdminAuditLogs,
} from './api';
import { DataTable } from '../../design_system/DataTable';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { FilterSelect } from '../../design_system/FilterSelect';
import { FormField } from '../../design_system/FormField';
import { LoadingState } from '../../design_system/LoadingState';
import { PageHeader } from '../../design_system/PageHeader';
import { Pagination } from '../../design_system/Pagination';
import { SearchInput } from '../../design_system/SearchInput';
import { SectionCard } from '../../design_system/SectionCard';
import { StatusBadge } from '../../design_system/StatusBadge';
import { TableToolbar } from '../../design_system/TableToolbar';

const phases = [
  { value: '', label: 'كل المراحل' },
  { value: 'ATTEMPT', label: 'بدأت' },
  { value: 'SUCCEEDED', label: 'نجحت' },
  { value: 'FAILED', label: 'فشلت' },
];

export function AuditLogsPage() {
  const [items, setItems] = useState<AdminAuditLog[]>([]);
  const [page, setPage] = useState(1);
  const [action, setAction] = useState('');
  const [actorUserId, setActorUserId] = useState('');
  const [phase, setPhase] = useState('');
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 20,
    total: 0,
    totalPages: 1,
  });
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const result = await getAdminAuditLogs({
        page,
        limit: 20,
        action,
        actorUserId,
        phase: (phase || undefined) as AdminAuditPhase | undefined,
      });
      if (page > result.totalPages) {
        setPage(result.totalPages);
        return;
      }
      setItems(result.items);
      setPagination({
        page: result.page,
        limit: result.limit,
        total: result.total,
        totalPages: result.totalPages,
      });
    } catch (value) {
      setError(
        value instanceof Error ? value.message : 'تعذر تحميل سجل التدقيق.',
      );
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, [page, phase]);

  function submitFilters() {
    if (page === 1) void load();
    else setPage(1);
  }

  if (isLoading) return <LoadingState title="جاري تحميل سجل التدقيق" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="الأمان والمساءلة"
        icon="⌁"
        title="سجل التدقيق الإداري"
        description="سجل تقني للعمليات الإدارية دون أجسام الطلبات أو المحتوى المالي. السجل للقراءة فقط ولا يمكن تعديله أو حذفه."
        meta={<span>{pagination.total} حدث مطابق</span>}
      />

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            label="بحث في سجل العمليات"
            value={action}
            onChange={setAction}
            onSubmit={submitFilters}
            placeholder="بحث بالعملية أو المسار"
          />
          <FormField
            label="معرّف المسؤول"
            value={actorUserId}
            onChange={(event) => setActorUserId(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === 'Enter') submitFilters();
            }}
            placeholder="اختياري"
          />
          <FilterSelect
            label="المرحلة"
            value={phase}
            onChange={(value) => {
              setPhase(value);
              setPage(1);
            }}
            options={phases}
          />
        </TableToolbar>
      </SectionCard>

      <SectionCard
        title="الأحداث غير القابلة للتعديل"
        subtitle="ATTEMPT يثبت بدء العملية، ثم SUCCEEDED أو FAILED يثبت نتيجتها. غياب المرحلة النهائية يكشف انقطاعا أثناء التنفيذ."
      >
        {items.length === 0 ? (
          <EmptyState
            title="لا توجد أحداث مطابقة"
            message="غيّر الفلاتر أو ابحث باسم عملية أخرى."
            tone="api"
          />
        ) : (
          <DataTable
            label="سجل عمليات الإدارة"
            columns={[
              'الوقت',
              'المسؤول',
              'الدور',
              'العملية',
              'الهدف',
              'النتيجة',
              'معرّف الطلب',
            ]}
            minWidth={1120}
          >
            {items.map((entry) => (
              <tr key={entry.id}>
                <td className="nowrap">{formatDate(entry.createdAt)}</td>
                <td className="nowrap">{entry.actorUserId}</td>
                <td>{roleLabel(entry.actorAdminRole)}</td>
                <td>
                  <strong dir="ltr">{entry.action}</strong>
                  <span className="table-subtle" dir="ltr">
                    event {entry.eventId}
                  </span>
                </td>
                <td dir="ltr">{entry.targetId ?? '—'}</td>
                <td>
                  <StatusBadge status={entry.phase} />
                  <span className="table-subtle">
                    {phaseLabel(entry.phase)}
                    {entry.statusCode ? ` · HTTP ${entry.statusCode}` : ''}
                    {entry.errorType ? ` · ${entry.errorType}` : ''}
                  </span>
                </td>
                <td dir="ltr">{entry.requestId ?? '—'}</td>
              </tr>
            ))}
          </DataTable>
        )}
        <Pagination
          page={pagination.page}
          limit={pagination.limit}
          total={pagination.total}
          totalPages={pagination.totalPages}
          onPageChange={setPage}
        />
      </SectionCard>
    </section>
  );
}

function phaseLabel(phase: AdminAuditPhase) {
  return phase === 'ATTEMPT'
    ? 'بدأت'
    : phase === 'SUCCEEDED'
      ? 'نجحت'
      : 'فشلت';
}

function roleLabel(role: AdminAuditLog['actorAdminRole']) {
  const labels = {
    SUPER_ADMIN: 'مدير أعلى',
    OPERATIONS: 'تشغيل',
    MODERATOR: 'إشراف محتوى',
    SUPPORT: 'دعم',
  };
  return labels[role];
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('ar-YE', {
    dateStyle: 'medium',
    timeStyle: 'medium',
  }).format(new Date(value));
}
