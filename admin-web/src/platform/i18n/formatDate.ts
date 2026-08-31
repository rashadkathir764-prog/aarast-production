export function formatDate(value?: string | null) {
  if (!value) return 'غير محدد';
  return new Intl.DateTimeFormat('ar-YE', {
    year: 'numeric', month: 'short', day: 'numeric',
  }).format(new Date(value));
}
