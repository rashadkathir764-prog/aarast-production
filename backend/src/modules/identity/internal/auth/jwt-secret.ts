const MINIMUM_PRODUCTION_SECRET_BYTES = 32;
const MINIMUM_PRODUCTION_SECRET_ENTROPY_BITS = 128;
const MINIMUM_PRODUCTION_UNIQUE_CHARACTERS = 12;

export function getJwtSecret(
  environment: NodeJS.ProcessEnv = process.env,
): string {
  const jwtSecret = environment.JWT_SECRET?.trim();

  if (!jwtSecret || isKnownPlaceholder(jwtSecret)) {
    throw new Error('JWT_SECRET is missing or unsafe');
  }

  if (
    environment.NODE_ENV === 'production' &&
    !isStrongProductionSecret(jwtSecret)
  ) {
    throw new Error(
      'JWT_SECRET does not meet the production strength requirements',
    );
  }

  return jwtSecret;
}

function isKnownPlaceholder(secret: string): boolean {
  const normalized = secret.toLowerCase();
  return (
    normalized === 'changeme' ||
    normalized === 'secret' ||
    normalized === 'jwt-secret' ||
    /(?:password|changeme|development|example|test[-_ ]?secret|replace[-_ ]?with|your[-_ ]?jwt)/i.test(
      secret,
    )
  );
}

function isStrongProductionSecret(secret: string): boolean {
  const byteLength = Buffer.byteLength(secret, 'utf8');
  const uniqueCharacters = new Set(secret).size;
  return (
    byteLength >= MINIMUM_PRODUCTION_SECRET_BYTES &&
    uniqueCharacters >= MINIMUM_PRODUCTION_UNIQUE_CHARACTERS &&
    estimatedEntropyBits(secret) >= MINIMUM_PRODUCTION_SECRET_ENTROPY_BITS
  );
}

function estimatedEntropyBits(value: string): number {
  const frequencies = new Map<string, number>();
  for (const character of value) {
    frequencies.set(character, (frequencies.get(character) ?? 0) + 1);
  }
  let entropyPerCharacter = 0;
  for (const count of frequencies.values()) {
    const probability = count / value.length;
    entropyPerCharacter -= probability * Math.log2(probability);
  }
  return entropyPerCharacter * value.length;
}
