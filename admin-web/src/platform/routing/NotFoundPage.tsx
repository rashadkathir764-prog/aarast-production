import { Link } from 'react-router-dom';

export function NotFoundPage() {
  return (
    <main className="login-page">
      <section className="login-card">
        <h1>الصفحة غير موجودة</h1>
        <p>المسار المطلوب غير متاح في لوحة إدارة اعّرست.</p>
        <Link className="button button--full" to="/">
          العودة للوحة التحكم
        </Link>
      </section>
    </main>
  );
}
