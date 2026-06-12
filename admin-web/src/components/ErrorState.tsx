type ErrorStateProps = {
  message: string;
  onRetry?: () => void;
};

export function ErrorState({ message, onRetry }: ErrorStateProps) {
  return (
    <div className="state-panel danger">
      <h2>تعذر تحميل البيانات</h2>
      <p>{message}</p>
      {onRetry ? (
        <button className="button ghost" onClick={onRetry}>
          إعادة المحاولة
        </button>
      ) : null}
    </div>
  );
}
