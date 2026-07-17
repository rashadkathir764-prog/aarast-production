import { FormEvent, useEffect, useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import {
  confirmAdminPasswordReset,
  requestAdminPasswordReset,
} from '../api/auth';
import { useAuth } from '../auth/AuthProvider';
import { FormField } from '../components/FormField';

type RecoveryStep = 'phone' | 'confirm' | null;

const neutralRecoveryNotice =
  'إذا كان الرقم مرتبطًا بحساب إدارة نشط، فسيصل رمز الاستعادة إلى واتساب.';

function isStrongAdminPassword(value: string): boolean {
  return (
    value.length >= 12 &&
    value.length <= 72 &&
    /[A-Za-z]/.test(value) &&
    /\d/.test(value)
  );
}

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
  const [recoveryStep, setRecoveryStep] = useState<RecoveryStep>(null);
  const [recoveryPhone, setRecoveryPhone] = useState('');
  const [recoveryChallengeToken, setRecoveryChallengeToken] = useState('');
  const [recoveryCode, setRecoveryCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newPasswordConfirmation, setNewPasswordConfirmation] = useState('');
  const [recoveryError, setRecoveryError] = useState<string | null>(null);
  const [recoveryNotice, setRecoveryNotice] = useState<string | null>(null);
  const [loginNotice, setLoginNotice] = useState<string | null>(null);
  const [isRecoveryLoading, setIsRecoveryLoading] = useState(false);
  const [retryRemaining, setRetryRemaining] = useState(0);
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: { pathname?: string } } | null)?.from
    ?.pathname;

  useEffect(() => {
    if (recoveryStep !== 'confirm' || retryRemaining <= 0) return undefined;
    const timeout = window.setTimeout(
      () => setRetryRemaining((remaining) => Math.max(0, remaining - 1)),
      1_000,
    );
    return () => window.clearTimeout(timeout);
  }, [recoveryStep, retryRemaining]);

  if (user) return <Navigate to={from ?? '/'} replace />;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (recoveryStep === 'phone') {
      await requestRecoveryCode();
      return;
    }
    if (recoveryStep === 'confirm') {
      await completeRecovery();
      return;
    }

    try {
      setLoginNotice(null);
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

  async function requestRecoveryCode() {
    const normalizedPhone = recoveryPhone.trim();
    setIsRecoveryLoading(true);
    setRecoveryError(null);
    setRecoveryNotice(null);
    try {
      const nextChallenge = await requestAdminPasswordReset(normalizedPhone);
      setRecoveryPhone(normalizedPhone);
      setRecoveryChallengeToken(nextChallenge.challengeToken);
      setRecoveryCode('');
      setRetryRemaining(nextChallenge.retryAfterSeconds);
      setRecoveryNotice(neutralRecoveryNotice);
      setRecoveryStep('confirm');
    } catch (err) {
      setRecoveryError(
        err instanceof Error ? err.message : 'تعذر بدء استعادة كلمة المرور.',
      );
    } finally {
      setIsRecoveryLoading(false);
    }
  }

  async function completeRecovery() {
    setRecoveryError(null);
    if (!isStrongAdminPassword(newPassword)) {
      setRecoveryError(
        'كلمة المرور يجب أن تكون من 12 إلى 72 خانة وتحتوي على حرف إنجليزي ورقم.',
      );
      return;
    }
    if (newPassword !== newPasswordConfirmation) {
      setRecoveryError('تأكيد كلمة المرور غير مطابق.');
      return;
    }
    if (!recoveryChallengeToken) {
      setRecoveryError('انتهى طلب الاستعادة. ابدأ طلبًا جديدًا.');
      return;
    }

    setIsRecoveryLoading(true);
    try {
      await confirmAdminPasswordReset(
        recoveryChallengeToken,
        recoveryCode,
        newPassword,
      );
      const restoredPhone = recoveryPhone;
      clearRecoveryState();
      setPhone(restoredPhone);
      setPassword('');
      setLoginNotice(
        'تم تغيير كلمة المرور وإلغاء الجلسات السابقة. سجل الدخول بكلمة المرور الجديدة.',
      );
    } catch (err) {
      setRecoveryError(
        err instanceof Error ? err.message : 'تعذر تغيير كلمة المرور.',
      );
    } finally {
      setIsRecoveryLoading(false);
    }
  }

  function startRecovery() {
    cancelMfa();
    setPassword('');
    clearRecoverySecrets();
    setRecoveryPhone(phone.trim());
    setLoginNotice(null);
    setRecoveryStep('phone');
  }

  function cancelRecovery() {
    const lastPhone = recoveryPhone.trim();
    clearRecoveryState();
    if (lastPhone) setPhone(lastPhone);
  }

  function clearRecoverySecrets() {
    setRecoveryChallengeToken('');
    setRecoveryCode('');
    setNewPassword('');
    setNewPasswordConfirmation('');
    setRetryRemaining(0);
  }

  function clearRecoveryState() {
    clearRecoverySecrets();
    setRecoveryPhone('');
    setRecoveryError(null);
    setRecoveryNotice(null);
    setRecoveryStep(null);
  }

  const isBusy = isLoading || isRecoveryLoading;
  const heading = challenge
    ? 'التحقق بخطوتين'
    : recoveryStep === 'phone'
      ? 'استعادة كلمة المرور'
      : recoveryStep === 'confirm'
        ? 'تعيين كلمة مرور جديدة'
        : 'مرحبا بك';
  const description = challenge
    ? 'أدخل الرمز المرسل إلى هاتف المسؤول لإكمال الجلسة الآمنة.'
    : recoveryStep === 'phone'
      ? 'أدخل رقم هاتف المسؤول. لن نكشف ما إذا كان الرقم مرتبطًا بحساب.'
      : recoveryStep === 'confirm'
        ? 'أدخل الرمز المرسل إلى واتساب، ثم اختر كلمة مرور إدارية قوية.'
        : 'أدخل كلمة المرور، ثم أكمل رمز التحقق للوصول إلى لوحة الإدارة.';
  const primaryLabel = isBusy
    ? 'جاري التحقق...'
    : challenge
      ? 'تحقق وافتح اللوحة'
      : recoveryStep === 'phone'
        ? 'إرسال رمز الاستعادة'
        : recoveryStep === 'confirm'
          ? 'تغيير كلمة المرور'
          : 'متابعة إلى رمز التحقق';

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
          <h2>{heading}</h2>
          <p>{description}</p>
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
          ) : recoveryStep === 'phone' ? (
            <FormField
              label="رقم هاتف المسؤول"
              value={recoveryPhone}
              onChange={(event) => setRecoveryPhone(event.target.value)}
              placeholder="770579680"
              autoComplete="username"
              inputMode="tel"
              required
              autoFocus
            />
          ) : recoveryStep === 'confirm' ? (
            <>
              <FormField
                label="رمز الاستعادة"
                value={recoveryCode}
                onChange={(event) =>
                  setRecoveryCode(event.target.value.replace(/\D/g, '').slice(0, 6))
                }
                autoComplete="one-time-code"
                inputMode="numeric"
                pattern="[0-9]{6}"
                minLength={6}
                maxLength={6}
                required
                autoFocus
              />
              <FormField
                label="كلمة المرور الجديدة"
                type="password"
                value={newPassword}
                onChange={(event) => setNewPassword(event.target.value)}
                autoComplete="new-password"
                minLength={12}
                maxLength={72}
                required
              />
              <FormField
                label="تأكيد كلمة المرور الجديدة"
                type="password"
                value={newPasswordConfirmation}
                onChange={(event) =>
                  setNewPasswordConfirmation(event.target.value)
                }
                autoComplete="new-password"
                minLength={12}
                maxLength={72}
                required
              />
              <p className="security-note">
                من 12 إلى 72 خانة، وتحتوي على حرف إنجليزي واحد ورقم واحد على الأقل.
              </p>
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
              <button
                className="button button--ghost button--full"
                type="button"
                disabled={isBusy}
                onClick={startRecovery}
              >
                نسيت كلمة المرور؟
              </button>
            </>
          )}
          {loginNotice && !recoveryStep && !challenge ? (
            <p className="security-note" role="status">
              {loginNotice}
            </p>
          ) : null}
          {recoveryNotice ? (
            <p className="security-note" role="status">
              {recoveryNotice}
            </p>
          ) : null}
          {recoveryStep && recoveryError ? (
            <p className="inline-error" role="alert">
              {recoveryError}
            </p>
          ) : !recoveryStep && error ? (
            <p className="inline-error" role="alert">
              {error}
            </p>
          ) : null}
          <button
            className="button button--full button--premium"
            disabled={isBusy}
            type="submit"
          >
            {primaryLabel}
          </button>
          {challenge ? (
            <button
              className="button button--ghost button--full"
              type="button"
              disabled={isBusy}
              onClick={() => {
                setCode('');
                cancelMfa();
              }}
            >
              العودة وتسجيل الدخول من جديد
            </button>
          ) : recoveryStep ? (
            <>
              {recoveryStep === 'confirm' ? (
                <button
                  className="button button--ghost button--full"
                  type="button"
                  disabled={isBusy || retryRemaining > 0}
                  onClick={() => void requestRecoveryCode()}
                >
                  {retryRemaining > 0
                    ? `إعادة الإرسال خلال ${retryRemaining} ث`
                    : 'إعادة إرسال الرمز'}
                </button>
              ) : null}
              <button
                className="button button--ghost button--full"
                type="button"
                disabled={isBusy}
                onClick={cancelRecovery}
              >
                العودة إلى تسجيل الدخول
              </button>
            </>
          ) : null}
          <p className="security-note">
            لا تُحفظ رموز الجلسة في تخزين المتصفح، وتُبطل الجلسة عند تسجيل الخروج.
          </p>
        </form>
      </section>
    </main>
  );
}
