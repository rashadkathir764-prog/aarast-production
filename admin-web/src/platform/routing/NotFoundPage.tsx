import { Link } from 'react-router-dom';
import '../../styles/desk.css';

/** An unknown address, on the desk kit like sign-in (D56; not drawn). */
export function NotFoundPage() {
  return (
    <main className="desk-gate">
      <section className="desk-panel desk-gate__card">
        <div className="desk-gate__brand">
          <span className="desk-wordmark">
            اعّرست
            <span className="desk-wordmark__dot" />
          </span>
          <span>لوحة الإدارة</span>
        </div>
        <h1 className="desk-gate__title">الصفحة غير موجودة</h1>
        <p className="desk-note">ما فيه صفحة بهذا العنوان في لوحة الإدارة.</p>
        <Link className="desk-btn desk-btn--teal desk-btn--full" to="/">
          ارجع للصندوق
        </Link>
      </section>
    </main>
  );
}
