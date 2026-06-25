import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

const LOCATION_LIMITS = {
  governorate: 120,
  cityOrDistrict: 160,
  areaOrNeighborhood: 160,
  street: 200,
  detailedAddress: 500,
} as const;

export interface WeddingLocationResponse {
  governorate?: string;
  cityOrDistrict?: string;
  areaOrNeighborhood?: string;
  street?: string;
  detailedAddress?: string;
  city?: string;
  district?: string;
  neighborhood?: string;
  addressNote?: string;
  shortLabel?: string;
  mediumLabel?: string;
  fullLabel?: string;
  displayLabel?: string;
}

export function normalizeWeddingLocationInput(
  value: Record<string, unknown> | null | undefined,
  cityFallback?: string | null,
): Prisma.InputJsonObject | null {
  if (!value) {
    const fallback = cleanOptionalText(cityFallback);
    return fallback ? toJsonObject({ cityOrDistrict: fallback }) : null;
  }

  const governorate = readText(value, 'governorate', LOCATION_LIMITS.governorate);
  const explicitCity = firstDefinedText(
    value,
    ['cityOrDistrict', 'city'],
    LOCATION_LIMITS.cityOrDistrict,
  );
  const district = readText(value, 'district', LOCATION_LIMITS.areaOrNeighborhood);
  const cityOrDistrict =
    explicitCity ??
    district ??
    cleanOptionalText(cityFallback, LOCATION_LIMITS.cityOrDistrict);
  const neighborhood = readText(
    value,
    'neighborhood',
    LOCATION_LIMITS.areaOrNeighborhood,
  );
  const areaOrNeighborhood =
    firstDefinedText(
      value,
      ['areaOrNeighborhood'],
      LOCATION_LIMITS.areaOrNeighborhood,
    ) ??
    neighborhood ??
    (district && district !== cityOrDistrict ? district : null);
  const street = readText(value, 'street', LOCATION_LIMITS.street);
  const detailedAddress = firstDefinedText(
    value,
    ['detailedAddress', 'addressNote', 'address'],
    LOCATION_LIMITS.detailedAddress,
  );

  const usesStructuredContract = [
    'cityOrDistrict',
    'areaOrNeighborhood',
    'detailedAddress',
  ].some((key) => Object.prototype.hasOwnProperty.call(value, key));

  if (usesStructuredContract && (!governorate || !cityOrDistrict)) {
    throw new BadRequestException(
      'location governorate and cityOrDistrict are required for structured location',
    );
  }

  return toJsonObject({
    governorate,
    cityOrDistrict,
    areaOrNeighborhood,
    street,
    detailedAddress,
  });
}

export function weddingLocationResponse(
  value: Prisma.JsonValue | null,
  cityFallback?: string | null,
): WeddingLocationResponse | null {
  const source =
    value && typeof value === 'object' && !Array.isArray(value)
      ? (value as Record<string, unknown>)
      : {};

  const governorate = tolerantText(source.governorate);
  const cityOrDistrict =
    tolerantText(source.cityOrDistrict) ??
    tolerantText(source.city) ??
    tolerantText(source.district) ??
    cleanOptionalText(cityFallback);
  const district = tolerantText(source.district);
  const areaOrNeighborhood =
    tolerantText(source.areaOrNeighborhood) ??
    tolerantText(source.neighborhood) ??
    (district && district !== cityOrDistrict ? district : null);
  const street = tolerantText(source.street);
  const detailedAddress =
    tolerantText(source.detailedAddress) ??
    tolerantText(source.addressNote) ??
    tolerantText(source.address);

  return buildLocationResponse({
    governorate,
    cityOrDistrict,
    areaOrNeighborhood,
    street,
    detailedAddress,
  });
}

export function cityFromWeddingLocation(
  value: Prisma.InputJsonObject | null,
): string | null {
  if (!value) return null;
  return (
    tolerantText(value.cityOrDistrict) ??
    tolerantText(value.city) ??
    tolerantText(value.district) ??
    tolerantText(value.governorate)
  );
}

function toJsonObject({
  governorate,
  cityOrDistrict,
  areaOrNeighborhood,
  street,
  detailedAddress,
}: {
  governorate?: string | null;
  cityOrDistrict?: string | null;
  areaOrNeighborhood?: string | null;
  street?: string | null;
  detailedAddress?: string | null;
}): Prisma.InputJsonObject | null {
  const response = buildLocationResponse({
    governorate,
    cityOrDistrict,
    areaOrNeighborhood,
    street,
    detailedAddress,
  });
  return response ? (response as Prisma.InputJsonObject) : null;
}

function buildLocationResponse({
  governorate,
  cityOrDistrict,
  areaOrNeighborhood,
  street,
  detailedAddress,
}: {
  governorate?: string | null;
  cityOrDistrict?: string | null;
  areaOrNeighborhood?: string | null;
  street?: string | null;
  detailedAddress?: string | null;
}): WeddingLocationResponse | null {
  const shortLabel = joinUnique([governorate, cityOrDistrict]);
  const mediumLabel = joinUnique([
    governorate,
    cityOrDistrict,
    areaOrNeighborhood,
  ]);
  const fullLabel = joinUnique([
    governorate,
    cityOrDistrict,
    areaOrNeighborhood,
    street,
    detailedAddress,
  ]);

  if (!fullLabel) return null;

  return {
    ...(governorate ? { governorate } : {}),
    ...(cityOrDistrict
      ? { cityOrDistrict, city: cityOrDistrict }
      : {}),
    ...(areaOrNeighborhood
      ? {
          areaOrNeighborhood,
          district: areaOrNeighborhood,
          neighborhood: areaOrNeighborhood,
        }
      : {}),
    ...(street ? { street } : {}),
    ...(detailedAddress
      ? { detailedAddress, addressNote: detailedAddress }
      : {}),
    ...(shortLabel ? { shortLabel } : {}),
    ...(mediumLabel ? { mediumLabel } : {}),
    ...(fullLabel ? { fullLabel, displayLabel: fullLabel } : {}),
  };
}

function firstDefinedText(
  source: Record<string, unknown>,
  keys: string[],
  maxLength: number,
): string | null {
  for (const key of keys) {
    const value = readText(source, key, maxLength);
    if (value) return value;
  }
  return null;
}

function readText(
  source: Record<string, unknown>,
  key: string,
  maxLength: number,
): string | null {
  const raw = source[key];
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== 'string') {
    throw new BadRequestException(`location.${key} must be a string`);
  }
  return cleanOptionalText(raw, maxLength, `location.${key}`);
}

function cleanOptionalText(
  value: string | null | undefined,
  maxLength = Number.MAX_SAFE_INTEGER,
  field = 'location',
): string | null {
  const trimmed = value?.trim() ?? '';
  if (!trimmed) return null;
  if (trimmed.length > maxLength) {
    throw new BadRequestException(
      `${field} must not exceed ${maxLength} characters`,
    );
  }
  return trimmed;
}

function tolerantText(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function joinUnique(values: (string | null | undefined)[]): string | null {
  const parts: string[] = [];
  for (const value of values) {
    const trimmed = value?.trim();
    if (!trimmed || parts.includes(trimmed)) continue;
    parts.push(trimmed);
  }
  return parts.length > 0 ? parts.join(' - ') : null;
}
