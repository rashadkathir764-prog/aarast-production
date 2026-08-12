import { getCorsOrigins } from './cors-origins';

export const CORS_METHODS = [
  'GET',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'OPTIONS',
] as const;

export const CORS_ALLOWED_HEADERS = [
  'Content-Type',
  'Authorization',
  'X-Client-Request-Id',
] as const;

export function getCorsOptions() {
  return {
    origin: getCorsOrigins(),
    credentials: true,
    methods: [...CORS_METHODS],
    allowedHeaders: [...CORS_ALLOWED_HEADERS],
  };
}
