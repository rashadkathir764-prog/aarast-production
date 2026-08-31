type ErrorStateProps = {
  message: string;
  onRetry?: () => void;
};

export function ErrorState({ message, onRetry }: ErrorStateProps) {
  return (
    <div className="state-panel state-panel--danger">
      <div className="state-mark danger" aria-hidden="true" />
      <h2>تعذر تحميل البيانات</h2>
      <p>{message}</p>
      {onRetry ? (
        <button className="button button--ghost" type="button" onClick={onRetry}>
          إعادة المحاولة
        </button>
      ) : null}
    </div>
  );
}
