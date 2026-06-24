export function getJwtSecret(): string {
  const jwtSecret = process.env.JWT_SECRET?.trim();

  if (!jwtSecret || jwtSecret.toLowerCase() === 'changeme') {
    throw new Error('JWT_SECRET is required and must not be changeme');
  }

  return jwtSecret;
}
