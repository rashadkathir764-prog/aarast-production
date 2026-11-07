import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { LoginPage } from './LoginPage';

const mocks = vi.hoisted(() => ({
  requestReset: vi.fn(),
  verifyReset: vi.fn(),
  confirmReset: vi.fn(),
  login: vi.fn(),
  verifyMfa: vi.fn(),
  cancelMfa: vi.fn(),
  challenge: null as null | { challengeToken: string; delivery: string },
}));

vi.mock('./transport', () => ({
  requestAdminPasswordReset: mocks.requestReset,
  verifyAdminPasswordReset: mocks.verifyReset,
  confirmAdminPasswordReset: mocks.confirmReset,
}));

vi.mock('./AuthProvider', () => ({
  useAuth: () => ({
    user: null,
    login: mocks.login,
    verifyMfa: mocks.verifyMfa,
    cancelMfa: mocks.cancelMfa,
    challenge: mocks.challenge,
    isLoading: false,
    error: null,
  }),
}));

function renderPage() {
  return render(
    <MemoryRouter initialEntries={['/login']}>
      <LoginPage />
    </MemoryRouter>,
  );
}

async function openRecoveryCode(phone = '777123456') {
  fireEvent.change(screen.getByLabelText('رقم الهاتف'), {
    target: { value: phone },
  });
  fireEvent.click(screen.getByRole('button', { name: 'نسيت كلمة المرور؟' }));
  fireEvent.click(screen.getByRole('button', { name: 'إرسال رمز الاستعادة' }));
  await screen.findByLabelText('رمز الاستعادة');
}

async function openRecoveryPassword() {
  await openRecoveryCode();
  fireEvent.change(screen.getByLabelText('رمز الاستعادة'), {
    target: { value: '123456' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'تحقق من الرمز' }));
  await screen.findByLabelText('كلمة المرور الجديدة');
}

function choosePassword(password: string, confirmation = password) {
  fireEvent.change(screen.getByLabelText('كلمة المرور الجديدة'), {
    target: { value: password },
  });
  fireEvent.change(screen.getByLabelText('تأكيد كلمة المرور الجديدة'), {
    target: { value: confirmation },
  });
  fireEvent.click(screen.getByRole('button', { name: 'حفظ كلمة المرور' }));
}

beforeEach(() => {
  vi.clearAllMocks();
  mocks.challenge = null;
  mocks.requestReset.mockResolvedValue({
    accepted: true,
    challengeToken: 'a'.repeat(64),
    expiresAt: '2026-07-17T12:10:00.000Z',
    retryAfterSeconds: 60,
    deliveryStatus: 'DELIVERED',
  });
  mocks.verifyReset.mockResolvedValue(undefined);
  mocks.confirmReset.mockResolvedValue(undefined);
});

describe('remembering this computer (RA-AD-11, D97)', () => {
  beforeEach(() => {
    mocks.challenge = { challengeToken: 'a'.repeat(64), delivery: 'DELIVERED' };
    mocks.verifyMfa.mockResolvedValue(undefined);
  });

  it('asks first, unchecked: the code is the second key on a shared computer', async () => {
    renderPage();
    const remember = screen.getByRole('checkbox', { name: /تذكّر هذا الجهاز/ });
    expect(remember).not.toBeChecked();
    fireEvent.change(screen.getByLabelText('رمز التحقق'), { target: { value: '123456' } });
    fireEvent.submit(screen.getByLabelText('رمز التحقق').closest('form')!);
    await waitFor(() => expect(mocks.verifyMfa).toHaveBeenCalledWith('123456', false));
  });

  it('remembers it when the admin ticks the box', async () => {
    renderPage();
    fireEvent.click(screen.getByRole('checkbox', { name: /تذكّر هذا الجهاز/ }));
    fireEvent.change(screen.getByLabelText('رمز التحقق'), { target: { value: '654321' } });
    fireEvent.submit(screen.getByLabelText('رمز التحقق').closest('form')!);
    await waitFor(() => expect(mocks.verifyMfa).toHaveBeenCalledWith('654321', true));
  });

  // RA-AD-16: the field kept Latin digits only, so a code typed on an
  // Arabic keyboard left it empty.
  it('reads a code typed in Arabic digits', async () => {
    renderPage();
    fireEvent.change(screen.getByLabelText('رمز التحقق'), { target: { value: '١٢٣٤٥٦' } });
    expect(screen.getByLabelText('رمز التحقق')).toHaveValue('123456');
    fireEvent.submit(screen.getByLabelText('رمز التحقق').closest('form')!);
    await waitFor(() => expect(mocks.verifyMfa).toHaveBeenCalledWith('123456', false));
  });
});

describe('a recovery code typed in Arabic digits (RA-AD-16)', () => {
  it('is read as the same code', async () => {
    renderPage();
    await openRecoveryCode();
    fireEvent.change(screen.getByLabelText('رمز الاستعادة'), { target: { value: '٦٥٤٣٢١' } });
    expect(screen.getByLabelText('رمز الاستعادة')).toHaveValue('654321');
    fireEvent.click(screen.getByRole('button', { name: 'تحقق من الرمز' }));
    await waitFor(() => expect(mocks.verifyReset).toHaveBeenCalledWith('a'.repeat(64), '654321'));
  });
});

describe('admin login surface', () => {
  it('keeps the entry point operational and free of retired decorative branding', () => {
    renderPage();

    // Sign-in is one desk panel (D56): the desk's wordmark and heading, no
    // slogan panel and none of the old maroon frame.
    expect(screen.getByRole('heading', { name: 'مرحباً بك', level: 1 })).toBeInTheDocument();
    expect(screen.getByText('لوحة الإدارة')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'دخول' })).toHaveClass('desk-btn');
    expect(screen.queryByText('قرارات واضحة، وبيانات مصونة.')).not.toBeInTheDocument();
    expect(screen.queryByText('مساحة تشغيل محمية')).not.toBeInTheDocument();
    expect(screen.queryByText('♕')).not.toBeInTheDocument();
    expect(document.querySelector('.login-brand-panel')).toBeNull();
    expect(document.querySelector('.login-card')).toBeNull();
  });
});

describe('admin password recovery', () => {
  it('clears the existing login password as soon as recovery starts', () => {
    renderPage();
    fireEvent.change(screen.getByLabelText('رقم الهاتف'), {
      target: { value: '777123456' },
    });
    fireEvent.change(screen.getByLabelText('كلمة المرور'), {
      target: { value: 'old-admin-password' },
    });

    fireEvent.click(screen.getByRole('button', { name: 'نسيت كلمة المرور؟' }));
    fireEvent.click(
      screen.getByRole('button', { name: 'العودة إلى تسجيل الدخول' }),
    );

    expect(screen.getByLabelText('كلمة المرور')).toHaveValue('');
  });

  it('asks for the code alone, before any password field', async () => {
    renderPage();
    await openRecoveryCode();

    expect(
      screen.getByRole('heading', { name: 'أدخل رمز الاستعادة', level: 1 }),
    ).toBeInTheDocument();
    expect(screen.queryByLabelText('كلمة المرور الجديدة')).not.toBeInTheDocument();
  });

  it('a wrong code stays on the code screen with its error', async () => {
    mocks.verifyReset.mockRejectedValueOnce(
      new Error('رمز الاستعادة غير صحيح أو انتهت صلاحيته.'),
    );
    renderPage();
    await openRecoveryCode();
    fireEvent.change(screen.getByLabelText('رمز الاستعادة'), {
      target: { value: '000000' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'تحقق من الرمز' }));

    expect(
      await screen.findByText('رمز الاستعادة غير صحيح أو انتهت صلاحيته.'),
    ).toBeInTheDocument();
    expect(screen.getByLabelText('رمز الاستعادة')).toBeInTheDocument();
    expect(screen.queryByLabelText('كلمة المرور الجديدة')).not.toBeInTheDocument();
  });

  it('uses neutral copy and returns to login without creating a session', async () => {
    renderPage();
    await openRecoveryCode();

    expect(mocks.requestReset).toHaveBeenCalledWith('777123456');
    expect(
      screen.getByText(
        'إذا كان الرقم مرتبطًا بحساب إدارة نشط، فقد تم تسليم رمز الاستعادة إلى واتساب.',
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText('أدخل الرمز الذي تم تسليمه إلى واتساب.'),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('رمز الاستعادة'), {
      target: { value: '123456' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'تحقق من الرمز' }));
    await screen.findByLabelText('كلمة المرور الجديدة');
    expect(mocks.verifyReset).toHaveBeenCalledWith('a'.repeat(64), '123456');
    expect(screen.queryByLabelText('رمز الاستعادة')).not.toBeInTheDocument();

    choosePassword('123456');

    await waitFor(() =>
      expect(mocks.confirmReset).toHaveBeenCalledWith('a'.repeat(64), '123456'),
    );
    expect(
      await screen.findByText(
        'تم تغيير كلمة المرور وإلغاء الجلسات السابقة. سجل الدخول بكلمة المرور الجديدة.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByLabelText('رقم الهاتف')).toHaveValue('777123456');
    expect(screen.queryByLabelText('كلمة المرور الجديدة')).not.toBeInTheDocument();
  });

  it('does not claim WhatsApp delivery when the transport is uncertain', async () => {
    mocks.requestReset.mockResolvedValueOnce({
      accepted: true,
      challengeToken: 'b'.repeat(64),
      expiresAt: '2026-07-17T12:10:00.000Z',
      retryAfterSeconds: 60,
      deliveryStatus: 'UNCERTAIN',
    });

    renderPage();
    await openRecoveryCode();

    expect(
      screen.getByText(
        'تم قبول طلب الاستعادة، لكن لم نتأكد من وصول الرمز إلى واتساب بعد.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByText('أدخل الرمز إذا وصلك عبر واتساب.')).toBeInTheDocument();
    expect(screen.queryByText(/تم تسليم رمز الاستعادة/)).not.toBeInTheDocument();
  });

  it('accepts digits-only or letters-only passwords of 6 or more', async () => {
    renderPage();
    await openRecoveryPassword();
    expect(
      screen.getByText('6 خانات على الأقل: أرقام أو حروف أو الاثنان معًا.'),
    ).toBeInTheDocument();

    choosePassword('12345');
    expect(
      await screen.findByText('كلمة المرور يجب أن تكون 6 خانات على الأقل.'),
    ).toBeInTheDocument();
    expect(mocks.confirmReset).not.toHaveBeenCalled();

    choosePassword('abcdef', 'abcdeg');
    expect(await screen.findByText('تأكيد كلمة المرور غير مطابق.')).toBeInTheDocument();
    expect(mocks.confirmReset).not.toHaveBeenCalled();

    choosePassword('abcdef');
    await waitFor(() =>
      expect(mocks.confirmReset).toHaveBeenCalledWith('a'.repeat(64), 'abcdef'),
    );
  });

  // RA-AD-16: the server stops a password at 72 bytes; a longer one was
  // refused here with «6 خانات على الأقل», which it already had.
  it('says a password past the server limit is too long, not too short', async () => {
    renderPage();
    await openRecoveryPassword();
    choosePassword('كلمة'.repeat(10));
    expect(
      await screen.findByText('كلمة المرور طويلة: 72 حرفًا إنجليزيًا أو 36 عربيًا بالكثير.'),
    ).toBeInTheDocument();
    expect(mocks.confirmReset).not.toHaveBeenCalled();
  });

  it('clears the challenge, code and new passwords when recovery is cancelled', async () => {
    renderPage();
    await openRecoveryPassword();
    fireEvent.change(screen.getByLabelText('كلمة المرور الجديدة'), {
      target: { value: 'Aarast-admin-2026' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'العودة إلى تسجيل الدخول' }));

    fireEvent.click(screen.getByRole('button', { name: 'نسيت كلمة المرور؟' }));
    fireEvent.click(screen.getByRole('button', { name: 'إرسال رمز الاستعادة' }));
    await screen.findByLabelText('رمز الاستعادة');

    expect(screen.getByLabelText('رمز الاستعادة')).toHaveValue('');
    expect(mocks.requestReset).toHaveBeenCalledTimes(2);

    fireEvent.change(screen.getByLabelText('رمز الاستعادة'), {
      target: { value: '123456' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'تحقق من الرمز' }));
    expect(await screen.findByLabelText('كلمة المرور الجديدة')).toHaveValue('');
  });
});
