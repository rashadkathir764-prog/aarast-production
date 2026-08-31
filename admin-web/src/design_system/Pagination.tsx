type PaginationProps = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  onPageChange: (page: number) => void;
};

export function Pagination({
  page,
  limit,
  total,
  totalPages,
  onPageChange,
}: PaginationProps) {
  const start = total === 0 ? 0 : (page - 1) * limit + 1;
  const end = Math.min(page * limit, total);
  const pageItems = visiblePages(page, totalPages);

  return (
    <nav className="pagination" aria-label="التنقل بين صفحات النتائج">
      <span className="pagination__summary">
        {start}–{end} من {total} نتيجة
      </span>
      <div className="pagination__controls">
        <button
          type="button"
          aria-label="الصفحة السابقة"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
        >
          السابق
        </button>
        {pageItems.map((item) =>
          typeof item === 'number' ? (
            <button
              type="button"
              key={item}
              aria-label={`الصفحة ${item}`}
              aria-current={item === page ? 'page' : undefined}
              onClick={() => onPageChange(item)}
            >
              {item}
            </button>
          ) : (
            <span className="pagination__ellipsis" aria-hidden="true" key={item}>
              …
            </span>
          ),
        )}
        <button
          type="button"
          aria-label="الصفحة التالية"
          disabled={page >= totalPages}
          onClick={() => onPageChange(page + 1)}
        >
          التالي
        </button>
      </div>
    </nav>
  );
}

type PageItem = number | 'ellipsis-start' | 'ellipsis-end';

function visiblePages(page: number, totalPages: number): PageItem[] {
  if (totalPages <= 7) {
    return Array.from({ length: totalPages }, (_, index) => index + 1);
  }
  if (page <= 4) {
    return [1, 2, 3, 4, 5, 'ellipsis-end', totalPages];
  }
  if (page >= totalPages - 3) {
    return [
      1,
      'ellipsis-start',
      totalPages - 4,
      totalPages - 3,
      totalPages - 2,
      totalPages - 1,
      totalPages,
    ];
  }
  return [
    1,
    'ellipsis-start',
    page - 1,
    page,
    page + 1,
    'ellipsis-end',
    totalPages,
  ];
}
