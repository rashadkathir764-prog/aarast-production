const statusMap: Record<string, { label: string; bg: string; color: string }> = {
  // الحالات المطابقة لجدول التصميم بالملي
  ACTIVE: { label: 'مؤكد', bg: '#EBF7EE', color: '#2D8A5D' },
  APPROVED: { label: 'مؤكد', bg: '#EBF7EE', color: '#2D8A5D' },
  PENDING_REVIEW: { label: 'قيد التنفيذ', bg: '#EBF3F9', color: '#1565C0' },
  NEEDS_CHANGES: { label: 'قيد المراجعة', bg: '#FFF8E1', color: '#B78103' },
  COMPLETED: { label: 'مكتمل', bg: '#F3EAEF', color: '#75646D' },
  CANCELLED: { label: 'ملغى', bg: '#FFEBEE', color: '#C62828' },
  REJECTED: { label: 'ملغى', bg: '#FFEBEE', color: '#C62828' },

  // بقية الحالات للحماية مع تنسيق متناسق
  PENDING: { label: 'جديد', bg: '#E3F2FD', color: '#0D47A1' },
  SUSPENDED: { label: 'موقوف', bg: '#F5F5F5', color: '#616161' },
  DISABLED: { label: 'معطل', bg: '#F5F5F5', color: '#616161' },
  OPEN: { label: 'مفتوح', bg: '#E3F2FD', color: '#0D47A1' },
  API_REQUIRED: { label: 'يتطلب API', bg: '#FFF3E0', color: '#E65100' },
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