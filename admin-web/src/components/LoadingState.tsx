import { LoadingSkeleton } from './LoadingSkeleton';

export function LoadingState({ title = 'جاري التحميل' }: { title?: string }) {
  return (
    <div className="state-panel">
      <LoadingSkeleton />
      <h2>{title}</h2>
      <p>لحظات فقط، يتم تجهيز البيانات.</p>
    </div>
  );
}
