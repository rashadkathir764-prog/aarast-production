export function getCorsOrigins(): false | (string | RegExp)[] {
  const configuredOrigins = process.env.CORS_ORIGINS?.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (configuredOrigins?.length) {
    return configuredOrigins;
  }

  if (process.env.NODE_ENV === 'production') {
    return false;
  }

  return [/^http:\/\/localhost:\d+$/, /^http:\/\/127\.0\.0\.1:\d+$/];
}
