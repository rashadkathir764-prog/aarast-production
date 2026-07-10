'use strict';

async function registerVerified(request, details) {
  const pending = await request('POST', '/auth/register', details);
  if (
    pending.status !== 201 ||
    pending.body?.registrationPending !== true
  ) {
    return pending;
  }

  const otpCode = process.env.SMOKE_OTP_CODE ?? pending.body?.code;
  if (typeof otpCode !== 'string' || !/^\d{6}$/.test(otpCode)) {
    throw new Error(
      'Verified registration smoke needs SMOKE_OTP_CODE or a local dev OTP response',
    );
  }

  return request('POST', '/auth/register/complete', { ...details, otpCode });
}

module.exports = { registerVerified };
