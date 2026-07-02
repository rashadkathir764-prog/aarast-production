const statusMap: Record<string, { label: string; bg: string; color: string }> = {
  ACTIVE: { label: 'نشط', bg: '#EBF7EE', color: '#2D8A5D' },
  APPROVED: { label: 'معتمد', bg: '#EBF7EE', color: '#2D8A5D' },
  PENDING_REVIEW: { label: 'قيد المراجعة', bg: '#EBF3F9', color: '#1565C0' },
  NEEDS_CHANGES: { label: 'يحتاج تعديل', bg: '#FFF8E1', color: '#B78103' },
  COMPLETED: { label: 'مكتمل', bg: '#F3EAEF', color: '#75646D' },
  CANCELLED: { label: 'ملغى', bg: '#FFEBEE', color: '#C62828' },
  REJECTED: { label: 'مرفوض', bg: '#FFEBEE', color: '#C62828' },
  PENDING: { label: 'قيد المراجعة', bg: '#E3F2FD', color: '#0D47A1' },
  SUSPENDED: { label: 'موقوف', bg: '#F5F5F5', color: '#616161' },
  DISABLED: { label: 'معطل', bg: '#F5F5F5', color: '#616161' },
  OPEN: { label: 'مفتوح', bg: '#E3F2FD', color: '#0D47A1' },
  PUBLISHED: { label: 'منشور', bg: '#EBF7EE', color: '#2D8A5D' },
  UNREAD: { label: 'غير مقروء', bg: '#E3F2FD', color: '#0D47A1' },
  READ: { label: 'مقروء', bg: '#F5F5F5', color: '#616161' },
  LOW: { label: 'منخفضة', bg: '#F5F5F5', color: '#616161' },
  NORMAL: { label: 'عادية', bg: '#EBF3F9', color: '#1565C0' },
  HIGH: { label: 'عالية', bg: '#FFF8E1', color: '#B78103' },
  URGENT: { label: 'عاجلة', bg: '#FFEBEE', color: '#C62828' },
};

export function StatusBadge({ status }: { status: string }) {
  const item = statusMap[status] ?? { label: status, bg: '#F5F5F5', color: '#616161' };

  return (
    <span 
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '4px 12px',
        borderRadius: '6px',
        fontSize: '11px',
        fontWeight: 600,
        backgroundColor: item.bg,
        color: item.color,
        whiteSpace: 'nowrap',
        lineHeight: 1.2
      }}
    >
      {item.label}
    </span>
  );
}

export function statusLabel(status: string) {
  return statusMap[status]?.label ?? status;
}
