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
      // AuthProvider exposes the user-facing error.
    }
  }

  return (
    <main className="login-page">
      <section className="login-card">
        <div className="brand centered">
          <strong>أعّرست</strong>
          <span>لوحة موافقات الموردين</span>
        </div>
        <form onSubmit={handleSubmit}>
          <FormField
            label="رقم الهاتف"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            placeholder="77xxxxxxx"
            autoComplete="username"
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
          <button className="button full" disabled={isLoading}>
            {isLoading ? 'جاري الدخول...' : 'تسجيل الدخول'}
          </button>
        </form>
      </section>
    </main>
  );
}
