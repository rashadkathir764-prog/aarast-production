import { FormEvent, useEffect, useState } from 'react';
import { ShieldCheck } from 'lucide-react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import {
  confirmAdminPasswordReset,
  requestAdminPasswordReset,
  type OtpDeliveryStatus,
} from './transport';
import { safeAdminReturnPath } from './admin-return-path';
import { useAuth } from './AuthProvider';
import { FormField } from '../../design_system/FormField';

type RecoveryStep = 'phone' | 'confirm' | null;

function neutralRecoveryNotice(deliveryStatus: OtpDeliveryStatus): string {
  return deliveryStatus === 'DELIVERED'
    ? 'إذا كان الرقم مرتبطًا بحساب إدارة نشط، فقد تم تسليم رمز الاستعادة إلى واتساب.'
    : 'تم قبول طلب الاستعادة، لكن لم نتأكد من وصول الرمز إلى واتساب بعد.';
}

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
    if (recoveryStep !== 'confirm' || retryRemaining <= 0) return undefined;
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
    if (recoveryStep === 'confirm') {
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
    setRecoveryDeliveryStatus(null);
    setRecoveryStep(null);
  }

  const isBusy = isLoading || isRecoveryLoading;
  const heading = challenge
    ? 'التحقق بخطوتين'
    : recoveryStep === 'phone'
      ? 'استعادة كلمة المرور'
      : recoveryStep === 'confirm'
        ? 'تعيين كلمة مرور جديدة'
        : 'مرحباً بك';
  const description = challenge
    ? challenge.deliveryStatus === 'DELIVERED'
      ? 'تم تسليم الرمز إلى واتساب المسؤول. أدخله لإكمال الجلسة الآمنة.'
      : 'طُلب إرسال الرمز، لكن لم نتأكد من وصوله بعد. أدخله إذا وصلك.'
    : recoveryStep === 'phone'
      ? 'أدخل رقم هاتف المسؤول. لن نكشف ما إذا كان الرقم مرتبطًا بحساب.'
      : recoveryStep === 'confirm'
        ? recoveryDeliveryStatus === 'DELIVERED'
          ? 'أدخل الرمز الذي تم تسليمه إلى واتساب، ثم اختر كلمة مرور إدارية قوية.'
          : 'أدخل الرمز إذا وصلك عبر واتساب، ثم اختر كلمة مرور إدارية قوية.'
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
      <section className="login-shell" aria-label="تسجيل دخول إدارة أعّرست">
        <aside className="login-context" aria-labelledby="admin-login-context-title">
          <div className="login-context__brand">
            <span className="login-context__mark" aria-hidden="true">
              <ShieldCheck size={20} strokeWidth={1.9} />
            </span>
            <div>
              <strong>أعّرست</strong>
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
          <p className="security-note login-card__security-note">
            لا تُحفظ رموز الجلسة في تخزين المتصفح، وتُبطل الجلسة عند تسجيل الخروج.
          </p>
        </form>
      </section>
    </main>
  );
}
