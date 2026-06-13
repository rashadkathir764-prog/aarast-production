type EmptyStateProps = {
  title: string;
  message: string;
  action?: React.ReactNode;
  tone?: 'default' | 'api';
};

export function EmptyState({
  title,
  message,
  action,
  tone = 'default',
}: EmptyStateProps) {
  return (
    <div className={`state-panel ${tone === 'api' ? 'state-panel--api' : ''}`}>
      <div className="empty-mark" aria-hidden="true">
        <span />
      </div>
      <h2>{title}</h2>
      <p>{message}</p>
      {action ? <div className="state-actions">{action}</div> : null}
    </div>
  );
}
