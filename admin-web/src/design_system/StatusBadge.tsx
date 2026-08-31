type StatusTone = 'default' | 'success' | 'warning' | 'danger' | 'info';

const statusMap: Record<string, { label: string; tone: StatusTone }> = {
  ACTIVE: { label: 'نشط', tone: 'success' },
  APPROVED: { label: 'معتمد', tone: 'success' },
  PENDING_REVIEW: { label: 'قيد المراجعة', tone: 'info' },
  NEEDS_CHANGES: { label: 'يحتاج تعديل', tone: 'warning' },
  COMPLETED: { label: 'مكتمل', tone: 'default' },
  CANCELLED: { label: 'ملغى', tone: 'danger' },
  REJECTED: { label: 'مرفوض', tone: 'danger' },
  PENDING: { label: 'قيد المراجعة', tone: 'info' },
  SUSPENDED: { label: 'موقوف', tone: 'default' },
  DISABLED: { label: 'معطل', tone: 'default' },
  OPEN: { label: 'مفتوح', tone: 'info' },
  REVIEWED: { label: 'تمت المراجعة', tone: 'success' },
  DISMISSED: { label: 'مرفوض', tone: 'default' },
  PUBLISHED: { label: 'منشور', tone: 'success' },
  UNREAD: { label: 'غير مقروء', tone: 'info' },
  READ: { label: 'مقروء', tone: 'default' },
  LOW: { label: 'منخفضة', tone: 'default' },
  NORMAL: { label: 'عادية', tone: 'info' },
  HIGH: { label: 'عالية', tone: 'warning' },
  URGENT: { label: 'عاجلة', tone: 'danger' },
  ATTEMPT: { label: 'بدأت', tone: 'warning' },
  SUCCEEDED: { label: 'نجحت', tone: 'success' },
  FAILED: { label: 'فشلت', tone: 'danger' },
};

export function StatusBadge({ status }: { status: string }) {
  const item = statusMap[status] ?? { label: status, tone: 'default' as const };

  return <span className={`status-badge ${item.tone}`}>{item.label}</span>;
}

export function statusLabel(status: string) {
  return statusMap[status]?.label ?? status;
}
