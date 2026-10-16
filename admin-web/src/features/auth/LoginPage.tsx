import { FormEvent, useEffect, useState } from 'react';
import { ShieldCheck } from 'lucide-react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import {
  confirmAdminPasswordReset,
  requestAdminPasswordReset,
  verifyAdminPasswordReset,
  type OtpDeliveryStatus,
} from './transport';
import { safeAdminReturnPath } from './admin-return-path';
import { useAuth } from './AuthProvider';
import { FormField } from '../../design_system/FormField';

// Recovery is three screens: the phone, the WhatsApp code, then the new
// password. The code is verified on its own screen, so choosing a password
// never races the code's expiry (the backend then allows 15 minutes).
type RecoveryStep = 'phone' | 'code' | 'password' | null;

function neutralRecoveryNotice(deliveryStatus: OtpDeliveryStatus): string {
  return deliveryStatus === 'DELIVERED'
    ? 'إذا كان الرقم مرتبطًا بحساب إدارة نشط، فقد تم تسليم رمز الاستعادة إلى واتساب.'
    : 'تم قبول طلب الاستعادة، لكن لم نتأكد من وصول الرمز إلى واتساب بعد.';
}

// The application rule: any letters or digits, 6 or more. Admin sign-in
// always asks for a WhatsApp code as well.
function isAcceptableAdminPassword(value: string): boolean {
  return value.length >= 6 && new TextEncoder().encode(value).length <= 72;
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
  const [recoveryDeliveryStatus, setRecoveryDeliveryStatus] = useState<
    OtpDeliveryStatus | null
  >(null);
  const [loginNotice, setLoginNotice] = useState<string | null>(null);
  const [isRecoveryLoading, setIsRecoveryLoading] = useState(false);
  const [retryRemaining, setRetryRemaining] = useState(0);
  const navigate = useNavigate();
  const location = useLocation();
  const returnPath = safeAdminReturnPath(
    (location.state as { from?: { pathname?: string } } | null)?.from?.pathname,
  );

  useEffect(() => {
    if (recoveryStep !== 'code' || retryRemaining <= 0) return undefined;
    const timeout = window.setTimeout(
      () => setRetryRemaining((remaining) => Math.max(0, remaining - 1)),
      1_000,
    );
    return () => window.clearTimeout(timeout);
  }, [recoveryStep, retryRemaining]);

  if (user) return <Navigate to={returnPath} replace />;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (recoveryStep === 'phone') {
      await requestRecoveryCode();
      return;
    }
    if (recoveryStep === 'code') {
      await verifyRecoveryCode();
      return;
    }
    if (recoveryStep === 'password') {
      await completeRecovery();
      return;
    }

    try {
      setLoginNotice(null);
      if (challenge) {
        await verifyMfa(code);
        navigate(returnPath, { replace: true });
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
    setRecoveryDeliveryStatus(null);
    try {
      const nextChallenge = await requestAdminPasswordReset(normalizedPhone);
      setRecoveryPhone(normalizedPhone);
      setRecoveryChallengeToken(nextChallenge.challengeToken);
      setRecoveryCode('');
      setRetryRemaining(nextChallenge.retryAfterSeconds);
      setRecoveryDeliveryStatus(nextChallenge.deliveryStatus);
      setRecoveryNotice(neutralRecoveryNotice(nextChallenge.deliveryStatus));
      setRecoveryStep('code');
    } catch (err) {
      setRecoveryError(
        err instanceof Error ? err.message : 'تعذر بدء استعادة كلمة المرور.',
      );
    } finally {
      setIsRecoveryLoading(false);
    }
  }

  async function verifyRecoveryCode() {
    setRecoveryError(null);
    if (!recoveryChallengeToken) {
      setRecoveryError('انتهى طلب الاستعادة. ابدأ طلبًا جديدًا.');
      return;
    }
    setIsRecoveryLoading(true);
    try {
      await verifyAdminPasswordReset(recoveryChallengeToken, recoveryCode);
      setRecoveryCode('');
      setRetryRemaining(0);
      setRecoveryNotice('تم التحقق من الرمز. اختر كلمة المرور الجديدة.');
      setRecoveryStep('password');
    } catch (err) {
      setRecoveryError(
        err instanceof Error ? err.message : 'تعذر التحقق من الرمز.',
      );
    } finally {
      setIsRecoveryLoading(false);
    }
  }

  async function completeRecovery() {
    setRecoveryError(null);
    if (!isAcceptableAdminPassword(newPassword)) {
      setRecoveryError('كلمة المرور يجب أن تكون 6 خانات على الأقل.');
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
      await confirmAdminPasswordReset(recoveryChallengeToken, newPassword);
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
    setRecoveryDeliveryStatus(null);
    setRecoveryStep(null);
  }

  const isBusy = isLoading || isRecoveryLoading;
  const heading = challenge
    ? 'التحقق بخطوتين'
    : recoveryStep === 'phone'
      ? 'استعادة كلمة المرور'
      : recoveryStep === 'code'
        ? 'أدخل رمز الاستعادة'
        : recoveryStep === 'password'
          ? 'تعيين كلمة مرور جديدة'
          : 'مرحباً بك';
  const description = challenge
    ? challenge.deliveryStatus === 'DELIVERED'
      ? 'تم تسليم الرمز إلى واتساب المسؤول. أدخله لإكمال الجلسة الآمنة.'
      : 'طُلب إرسال الرمز، لكن لم نتأكد من وصوله بعد. أدخله إذا وصلك.'
    : recoveryStep === 'phone'
      ? 'أدخل رقم هاتف المسؤول. لن نكشف ما إذا كان الرقم مرتبطًا بحساب.'
      : recoveryStep === 'code'
        ? recoveryDeliveryStatus === 'DELIVERED'
          ? 'أدخل الرمز الذي تم تسليمه إلى واتساب.'
          : 'أدخل الرمز إذا وصلك عبر واتساب.'
        : recoveryStep === 'password'
          ? 'اختر كلمة المرور الجديدة. لديك 15 دقيقة.'
          : 'أدخل كلمة المرور، ثم أكمل رمز التحقق للوصول إلى لوحة الإدارة.';
  const primaryLabel = isBusy
    ? 'جاري التحقق...'
    : challenge
      ? 'تحقق وافتح اللوحة'
      : recoveryStep === 'phone'
        ? 'إرسال رمز الاستعادة'
        : recoveryStep === 'code'
          ? 'تحقق من الرمز'
          : recoveryStep === 'password'
            ? 'حفظ كلمة المرور'
            : 'دخول';

  return (
    <main className="login-page">
      <section className="login-shell" aria-label="تسجيل دخول إدارة اعّرست">
        <aside className="login-context" aria-labelledby="admin-login-context-title">
          <div className="login-context__brand">
            <span className="login-context__mark" aria-hidden="true">
              <ShieldCheck size={20} strokeWidth={1.9} />
            </span>
            <div>
              <strong>اعّرست</strong>
              <span>إدارة المنصة</span>
            </div>
          </div>

          <div className="login-context__copy">
            <span className="eyebrow">مساحة تشغيل محمية</span>
            <h1 id="admin-login-context-title">قرارات واضحة، وبيانات مصونة.</h1>
            <p>
              راجع الطلبات والكتالوج وسلامة الحسابات من مكان واحد، وبصلاحيات
              إدارية محددة.
            </p>
          </div>

          <ul className="login-context__principles">
            <li>اعتماد الموردين ومراجعة التغييرات حسب صلاحيتك.</li>
            <li>إدارة الكتالوج دون كشف تفاصيل التخطيط والمال الخاصة.</li>
            <li>رمز تحقق وجلسات خاضعة للإبطال للحفاظ على الوصول الإداري.</li>
          </ul>
        </aside>

        <form className="login-card" onSubmit={handleSubmit}>
          <header className="login-card__header">
            <span className="login-card__mark" aria-hidden="true">
              <ShieldCheck size={22} strokeWidth={1.9} />
            </span>
            <div>
              <span className="eyebrow">بوابة الإدارة</span>
              <h2>{heading}</h2>
              <p>{description}</p>
            </div>
          </header>
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
              placeholder="7XXXXXXXX"
              autoComplete="username"
              inputMode="tel"
              required
              autoFocus
            />
          ) : recoveryStep === 'code' ? (
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
          ) : recoveryStep === 'password' ? (
            <>
              <FormField
                label="كلمة المرور الجديدة"
                type="password"
                value={newPassword}
                onChange={(event) => setNewPassword(event.target.value)}
                autoComplete="new-password"
                minLength={6}
                maxLength={72}
                required
                autoFocus
              />
              <FormField
                label="تأكيد كلمة المرور الجديدة"
                type="password"
                value={newPasswordConfirmation}
                onChange={(event) =>
                  setNewPasswordConfirmation(event.target.value)
                }
                autoComplete="new-password"
                minLength={6}
                maxLength={72}
                required
              />
              <p className="security-note">
                6 خانات على الأقل: أرقام أو حروف أو الاثنان معًا.
              </p>
            </>
          ) : (
            <>
              <FormField
                label="رقم الهاتف"
                value={phone}
                onChange={(event) => setPhone(event.target.value)}
                placeholder="7XXXXXXXX"
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
            className="button button--full"
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
              {recoveryStep === 'code' ? (
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
          <p className="security-note login-card__security-note">
            لا تُحفظ رموز الجلسة في تخزين المتصفح، وتُبطل الجلسة عند تسجيل الخروج.
          </p>
        </form>
      </section>
    </main>
  );
}
