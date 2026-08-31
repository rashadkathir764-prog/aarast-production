import { CheckCircle2, XCircle } from 'lucide-react';
import { useEffect, useState } from 'react';
import {
  ConversationReport,
  getConversationReports,
  updateConversationReportStatus,
} from './api';
import { ActionButton } from '../../design_system/ActionButton';
import { DataTable } from '../../design_system/DataTable';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { FilterSelect } from '../../design_system/FilterSelect';
import { LoadingState } from '../../design_system/LoadingState';
import { PageHeader } from '../../design_system/PageHeader';
import { Pagination } from '../../design_system/Pagination';
import { SectionCard } from '../../design_system/SectionCard';
import { StatCard } from '../../design_system/StatCard';
import { StatusBadge } from '../../design_system/StatusBadge';
import { TableToolbar } from '../../design_system/TableToolbar';
import { Can } from '../auth/api';
import { AdminPermission } from '../auth/api';

const statuses = [
  { value: '', label: 'كل الحالات' },
  { value: 'OPEN', label: 'مفتوحة' },
  { value: 'REVIEWED', label: 'تمت مراجعتها' },
  { value: 'DISMISSED', label: 'مرفوضة' },
];

export function ConversationReportsPage() {
  const [reports, setReports] = useState<ConversationReport[]>([]);
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 20,
    total: 0,
    totalPages: 1,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const result = await getConversationReports({ status, page, limit: 20 });
      if (page > result.totalPages) {
        setPage(result.totalPages);
        return;
      }
      setReports(result.items);
      setPagination({
        page: result.page,
        limit: result.limit,
        total: result.total,
        totalPages: result.totalPages,
      });
    } catch (value) {
      setError(value instanceof Error ? value.message : 'تعذر تحميل البلاغات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, [status, page]);

  async function update(
    report: ConversationReport,
    nextStatus: ConversationReport['status'],
  ) {
    setUpdatingId(report.id);
    setError(null);
    try {
      await updateConversationReportStatus(report.id, nextStatus);
      await load();
    } catch (value) {
      setError(value instanceof Error ? value.message : 'تعذر تحديث البلاغ.');
    } finally {
      setUpdatingId(null);
    }
  }

  if (isLoading) return <LoadingState title="جاري تحميل بلاغات المحادثات" />;
  if (error && reports.length === 0) {
    return <ErrorState message={error} onRetry={load} />;
  }

  const openCount = reports.filter((report) => report.status === 'OPEN').length;
  const reviewedCount = reports.filter(
    (report) => report.status === 'REVIEWED',
  ).length;
  const dismissedCount = reports.filter(
    (report) => report.status === 'DISMISSED',
  ).length;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="السلامة والثقة"
        icon="!"
        title="بلاغات المحادثات"
        description="مراجعة البلاغات المرتبطة بطلبات الأسعار دون إظهار محتوى الرسائل أو البيانات المالية."
        meta={<span>{pagination.total} بلاغ مطابق</span>}
      />

      <div className="stats-grid">
        <StatCard title="كل النتائج" value={pagination.total} tone="gold" />
        <StatCard title="مفتوحة في الصفحة" value={openCount} tone="warning" />
        <StatCard title="مراجعة مكتملة في الصفحة" value={reviewedCount} tone="success" />
        <StatCard title="مرفوضة في الصفحة" value={dismissedCount} tone="info" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <FilterSelect
            label="الحالة"
            value={status}
            onChange={(value) => {
              setStatus(value);
              setPage(1);
            }}
            options={statuses}
          />
        </TableToolbar>
      </SectionCard>

      {error ? <ErrorState message={error} onRetry={load} /> : null}

      <SectionCard
        title="قائمة البلاغات"
        subtitle="تظهر هوية المبلّغ وسياق المزود فقط، ولا تعرض سجل المحادثة."
      >
        {reports.length === 0 ? (
          <EmptyState
            title="لا توجد بلاغات مطابقة"
            message="غيّر فلتر الحالة لمراجعة بقية البلاغات."
            tone="api"
          />
        ) : (
          <DataTable
            label="بلاغات المحادثات"
            columns={[
              'المبلّغ',
              'المزود',
              'السبب',
              'الحالة',
              'التاريخ',
              'إجراءات',
            ]}
            minWidth={980}
          >
            {reports.map((report) => (
              <tr key={report.id}>
                <td>
                  <strong>{report.reporter.name}</strong>
                  <span className="table-subtle" dir="ltr">
                    {report.reporter.phone ?? 'لا يوجد رقم'}
                  </span>
                </td>
                <td>
                  {report.conversation.provider.businessName}
                  <span className="table-subtle">
                    {report.conversation.quoteRequests[0]
                      ? `آخر طلب ${report.conversation.quoteRequests[0].id}`
                      : 'لا توجد طلبات مرتبطة'}
                  </span>
                </td>
                <td>{report.reason}</td>
                <td><StatusBadge status={report.status} /></td>
                <td>{formatDate(report.createdAt)}</td>
                <td className="actions-cell">
                  <Can permission={AdminPermission.CONVERSATION_REPORTS_WRITE}>
                    {report.status !== 'REVIEWED' ? (
                    <ActionButton
                      icon={<CheckCircle2 size={16} />}
                      tone="ghost"
                      size="small"
                      disabled={updatingId === report.id}
                      onClick={() => update(report, 'REVIEWED')}
                    >
                      تمت المراجعة
                    </ActionButton>
                    ) : null}
                    {report.status !== 'DISMISSED' ? (
                    <ActionButton
                      icon={<XCircle size={16} />}
                      tone="danger"
                      size="small"
                      disabled={updatingId === report.id}
                      onClick={() => update(report, 'DISMISSED')}
                    >
                      رفض البلاغ
                    </ActionButton>
                    ) : null}
                  </Can>
                </td>
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

function formatDate(value: string) {
  return new Intl.DateTimeFormat('ar-YE', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
