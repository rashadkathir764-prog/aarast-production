const statusMap: Record<string, { label: string; tone: string }> = {
  PENDING: { label: 'قيد المراجعة', tone: 'warning' },
  PENDING_REVIEW: { label: 'قيد المراجعة', tone: 'warning' },
  ACTIVE: { label: 'نشط', tone: 'success' },
  APPROVED: { label: 'نشط', tone: 'success' },
  NEEDS_CHANGES: { label: 'يحتاج تعديل', tone: 'info' },
  REJECTED: { label: 'مرفوض', tone: 'danger' },
  SUSPENDED: { label: 'موقوف', tone: 'muted' },
};

export function StatusBadge({ status }: { status: string }) {
  const item = statusMap[status] ?? { label: status, tone: 'muted' };
  return <span className={`status-badge ${item.tone}`}>{item.label}</span>;
}

export function statusLabel(status: string) {
  return statusMap[status]?.label ?? status;
}
