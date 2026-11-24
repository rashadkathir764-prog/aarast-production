import { SetMetadata } from '@nestjs/common';

export const SKIP_IDEMPOTENCY_STORE = 'aarast:skip-idempotency-store';

/**
 * RA-BE-159: a route whose response must never become a replay row. The
 * planning assistant's answers are generated text the app promises to keep
 * nowhere; such a route runs on every request, its `X-Client-Request-Id`
 * reserves nothing and its response is stored nowhere.
 */
export const SkipIdempotencyStore = () => SetMetadata(SKIP_IDEMPOTENCY_STORE, true);
