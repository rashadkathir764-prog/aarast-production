import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { LoginPage } from './LoginPage';

const mocks = vi.hoisted(() => ({
  requestReset: vi.fn(),
  confirmReset: vi.fn(),
  login: vi.fn(),
  verifyMfa: vi.fn(),
  cancelMfa: vi.fn(),
}));

vi.mock('../api/auth', () => ({
  requestAdminPasswordReset: mocks.requestReset,
  confirmAdminPasswordReset: mocks.confirmReset,
}));

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    user: null,
    login: mocks.login,
    verifyMfa: mocks.verifyMfa,
    cancelMfa: mocks.cancelMfa,
    challenge: null,
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

async function openRecoveryConfirmation(phone = '777123456') {
  fireEvent.change(screen.getByLabelText('رقم الهاتف'), {
    target: { value: phone },
  });
  fireEvent.click(screen.getByRole('button', { name: 'نسيت كلمة المرور؟' }));
  fireEvent.click(screen.getByRole('button', { name: 'إرسال رمز الاستعادة' }));
  await screen.findByLabelText('رمز الاستعادة');
}

beforeEach(() => {
  vi.clearAllMocks();
  mocks.requestReset.mockResolvedValue({
    accepted: true,
    challengeToken: 'a'.repeat(64),
    expiresAt: '2026-07-17T12:10:00.000Z',
    retryAfterSeconds: 60,
    deliveryStatus: 'DELIVERED',
  });
  mocks.confirmReset.mockResolvedValue(undefined);
});

describe('admin login surface', () => {
  it('keeps the entry point operational and free of retired decorative branding', () => {
    renderPage();

    expect(
      screen.getByRole('heading', {
        name: 'قرارات واضحة، وبيانات مصونة.',
        level: 1,
      }),
    ).toBeInTheDocument();
    expect(screen.getByText('مساحة تشغيل محمية')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'مرحباً بك', level: 2 })).toBeInTheDocument();
    expect(screen.queryByText('♕')).not.toBeInTheDocument();
    expect(document.querySelector('.login-brand-panel')).toBeNull();
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

  it('states that the recovery password requires an English letter', async () => {
    renderPage();
    await openRecoveryConfirmation();

    expect(
      screen.getByText(
        'من 12 إلى 72 خانة، وتحتوي على حرف إنجليزي واحد ورقم واحد على الأقل.',
      ),
    ).toBeInTheDocument();
  });

  it('uses neutral copy and returns to login without creating a session', async () => {
    renderPage();
    await openRecoveryConfirmation();

    expect(mocks.requestReset).toHaveBeenCalledWith('777123456');
    expect(
      screen.getByText(
        'إذا كان الرقم مرتبطًا بحساب إدارة نشط، فقد تم تسليم رمز الاستعادة إلى واتساب.',
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        'أدخل الرمز الذي تم تسليمه إلى واتساب، ثم اختر كلمة مرور إدارية قوية.',
      ),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('رمز الاستعادة'), {
      target: { value: '123456' },
    });
    fireEvent.change(screen.getByLabelText('كلمة المرور الجديدة'), {
      target: { value: 'Aarast-admin-2026' },
    });
    fireEvent.change(screen.getByLabelText('تأكيد كلمة المرور الجديدة'), {
      target: { value: 'Aarast-admin-2026' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'تغيير كلمة المرور' }));

    await waitFor(() =>
      expect(mocks.confirmReset).toHaveBeenCalledWith(
        'a'.repeat(64),
        '123456',
        'Aarast-admin-2026',
      ),
    );
    expect(
      await screen.findByText(
        'تم تغيير كلمة المرور وإلغاء الجلسات السابقة. سجل الدخول بكلمة المرور الجديدة.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByLabelText('رقم الهاتف')).toHaveValue('777123456');
    expect(screen.queryByLabelText('رمز الاستعادة')).not.toBeInTheDocument();
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
    await openRecoveryConfirmation();

    expect(
      screen.getByText(
        'تم قبول طلب الاستعادة، لكن لم نتأكد من وصول الرمز إلى واتساب بعد.',
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        'أدخل الرمز إذا وصلك عبر واتساب، ثم اختر كلمة مرور إدارية قوية.',
      ),
    ).toBeInTheDocument();
    expect(screen.queryByText(/تم تسليم رمز الاستعادة/)).not.toBeInTheDocument();
  });

  it('does not submit a weak or mismatched administrator password', async () => {
    renderPage();
    await openRecoveryConfirmation();

    fireEvent.change(screen.getByLabelText('رمز الاستعادة'), {
      target: { value: '123456' },
    });
    fireEvent.change(screen.getByLabelText('كلمة المرور الجديدة'), {
      target: { value: 'short123' },
    });
    fireEvent.change(screen.getByLabelText('تأكيد كلمة المرور الجديدة'), {
      target: { value: 'short123' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'تغيير كلمة المرور' }));

    expect(
      await screen.findByText(
        'كلمة المرور يجب أن تكون من 12 إلى 72 خانة وتحتوي على حرف إنجليزي ورقم.',
      ),
    ).toBeInTheDocument();
    expect(mocks.confirmReset).not.toHaveBeenCalled();

    fireEvent.change(screen.getByLabelText('كلمة المرور الجديدة'), {
      target: { value: 'Aarast-admin-2026' },
    });
    fireEvent.change(screen.getByLabelText('تأكيد كلمة المرور الجديدة'), {
      target: { value: 'Aarast-admin-2027' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'تغيير كلمة المرور' }));

    expect(
      await screen.findByText('تأكيد كلمة المرور غير مطابق.'),
    ).toBeInTheDocument();
    expect(mocks.confirmReset).not.toHaveBeenCalled();
  });

  it('clears the challenge, code and new passwords when recovery is cancelled', async () => {
    renderPage();
    await openRecoveryConfirmation();

    fireEvent.change(screen.getByLabelText('رمز الاستعادة'), {
      target: { value: '123456' },
    });
    fireEvent.change(screen.getByLabelText('كلمة المرور الجديدة'), {
      target: { value: 'Aarast-admin-2026' },
    });
    fireEvent.change(screen.getByLabelText('تأكيد كلمة المرور الجديدة'), {
      target: { value: 'Aarast-admin-2026' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'العودة إلى تسجيل الدخول' }));

    fireEvent.click(screen.getByRole('button', { name: 'نسيت كلمة المرور؟' }));
    fireEvent.click(screen.getByRole('button', { name: 'إرسال رمز الاستعادة' }));
    await screen.findByLabelText('رمز الاستعادة');

    expect(screen.getByLabelText('رمز الاستعادة')).toHaveValue('');
    expect(screen.getByLabelText('كلمة المرور الجديدة')).toHaveValue('');
    expect(screen.getByLabelText('تأكيد كلمة المرور الجديدة')).toHaveValue('');
    expect(mocks.requestReset).toHaveBeenCalledTimes(2);
  });
});
