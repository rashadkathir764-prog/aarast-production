import { FormEvent, useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { FormField } from '../components/FormField';

export function LoginPage() {
  const { user, login, isLoading, error } = useAuth();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: { pathname?: string } } | null)?.from
    ?.pathname;

  if (user) return <Navigate to={from ?? '/'} replace />;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    try {
      await login(phone.trim(), password);
      navigate(from ?? '/', { replace: true });
    } catch {
      // AuthProvider exposes the Arabic user-facing error.
    }
  }

  return (
    <main className="login-page">
      <section className="login-shell" aria-label="تسجيل دخول إدارة أعرست">
        <div className="login-brand-panel">
          <div className="login-brand-panel__content">
            <span className="brand-crown" aria-hidden="true">
              ♕
            </span>
            <h1>أعرست</h1>
            <p>لوحة إدارة منصة الأعراس</p>
            <ul>
              <li>اعتماد الموردين والتحقق من جودة كل ملف.</li>
              <li>إدارة المدن والفئات دون كشف بيانات حساسة.</li>
              <li>متابعة حالة السوق من واجهة إدارية آمنة.</li>
            </ul>
          </div>
        </div>

        <form className="login-card" onSubmit={handleSubmit}>
          <div className="login-card__mark" aria-hidden="true">
            ♕
          </div>
          <span className="eyebrow">بوابة الإدارة</span>
          <h2>مرحبا بك</h2>
          <p>سجل الدخول للوصول إلى لوحة إدارة أعرست.</p>
          <FormField
            label="رقم الهاتف"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            placeholder="770579680"
            autoComplete="username"
            inputMode="tel"
            required
          />
          <FormField
            label="كلمة المرور"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="current-password"
            required
          />
          {error ? <p className="inline-error">{error}</p> : null}
          <button className="button button--full button--premium" disabled={isLoading}>
            {isLoading ? 'جاري الدخول...' : 'دخول كمسؤول'}
          </button>
          <p className="security-note">
            لا يتم عرض أي بيانات داخلية قبل تسجيل الدخول
          </p>
        </form>
      </section>
    </main>
  );
}
