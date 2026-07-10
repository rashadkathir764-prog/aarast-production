import { FormEvent, useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { FormField } from '../components/FormField';

export function LoginPage() {
  const {
    user,
    login,
    verifyMfa,
    cancelMfa,
    challenge,
    isLoading,
    error,
  } = useAuth();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: { pathname?: string } } | null)?.from
    ?.pathname;

  if (user) return <Navigate to={from ?? '/'} replace />;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    try {
      if (challenge) {
        await verifyMfa(code);
        navigate(from ?? '/', { replace: true });
      } else {
        await login(phone.trim(), password);
        setPassword('');
      }
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
          <h2>{challenge ? 'التحقق بخطوتين' : 'مرحبا بك'}</h2>
          <p>
            {challenge
              ? 'أدخل الرمز المرسل إلى هاتف المسؤول لإكمال الجلسة الآمنة.'
              : 'أدخل كلمة المرور، ثم أكمل رمز التحقق للوصول إلى لوحة الإدارة.'}
          </p>
          {challenge ? (
            <>
              <FormField
                label="رمز التحقق"
                value={code}
                onChange={(event) =>
                  setCode(event.target.value.replace(/\D/g, '').slice(0, 6))
                }
                autoComplete="one-time-code"
                inputMode="numeric"
                pattern="[0-9]{6}"
                minLength={6}
                maxLength={6}
                required
                autoFocus
              />
              {challenge.delivery === 'LOCAL_DEV' && challenge.code ? (
                <p className="security-note">رمز التطوير المحلي: {challenge.code}</p>
              ) : null}
            </>
          ) : (
            <>
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
            </>
          )}
          {error ? <p className="inline-error">{error}</p> : null}
          <button className="button button--full button--premium" disabled={isLoading}>
            {isLoading
              ? 'جاري التحقق...'
              : challenge
                ? 'تحقق وافتح اللوحة'
                : 'متابعة إلى رمز التحقق'}
          </button>
          {challenge ? (
            <button
              className="button button--ghost button--full"
              type="button"
              disabled={isLoading}
              onClick={() => {
                setCode('');
                cancelMfa();
              }}
            >
              العودة وتسجيل الدخول من جديد
            </button>
          ) : null}
          <p className="security-note">
            لا تُحفظ رموز الجلسة في تخزين المتصفح، وتُبطل الجلسة عند تسجيل الخروج.
          </p>
        </form>
      </section>
    </main>
  );
}
