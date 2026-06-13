const statusMap: Record<string, { label: string; tone: string }> = {
  PENDING: { label: 'جديد', tone: 'info' },
  PENDING_REVIEW: { label: 'قيد المراجعة', tone: 'warning' },
  ACTIVE: { label: 'نشط', tone: 'success' },
  APPROVED: { label: 'مقبول', tone: 'success' },
  NEEDS_CHANGES: { label: 'يحتاج تعديل', tone: 'gold' },
  REJECTED: { label: 'مرفوض', tone: 'danger' },
  SUSPENDED: { label: 'موقوف', tone: 'muted' },
  DISABLED: { label: 'معطل', tone: 'muted' },
  OPEN: { label: 'مفتوح', tone: 'info' },
  COMPLETED: { label: 'مكتمل', tone: 'success' },
  CANCELLED: { label: 'ملغى', tone: 'danger' },
  API_REQUIRED: { label: 'يتطلب API', tone: 'gold' },
};

export function StatusBadge({ status }: { status: string }) {
  const item = statusMap[status] ?? { label: status, tone: 'muted' };
  return <span className={`status-badge ${item.tone}`}>{item.label}</span>;
}

export function statusLabel(status: string) {
  return statusMap[status]?.label ?? status;
}
