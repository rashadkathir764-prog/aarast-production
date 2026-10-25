import { BadRequestException } from "@nestjs/common";
import { isUUID } from "class-validator";
import type { ProviderSearchWhere } from "./marketplace.contracts";
import type { ListProvidersQueryDto } from "./dto/list-providers-query.dto";

/** At most this many categories in one `categoryIds`. */
const MAX_CATEGORY_IDS = 50;

/**
 * The directory's category filter: `categoryId`, or G40's `categoryIds` (a
 * money item's `providerCategoryIds`, comma-separated); a provider whose own
 * kind or any active service is in one of them is listed. Null lists every
 * category. Both at once is a 400.
 */
export function providerCategoryFilter(
  query: Pick<ListProvidersQueryDto, "categoryId" | "categoryIds">,
): ProviderSearchWhere["AND"][number] | null {
  const ids = providerCategoryIds(query);
  if (!ids) return null;
  return {
    OR: [
      { primaryCategoryId: { in: ids } },
      { services: { some: { categoryId: { in: ids }, isActive: true } } },
    ],
  };
}

function providerCategoryIds(
  query: Pick<ListProvidersQueryDto, "categoryId" | "categoryIds">,
): string[] | null {
  const many = query.categoryIds?.trim() || null;
  if (query.categoryId && many) {
    throw new BadRequestException("Send categoryId or categoryIds, not both");
  }
  if (query.categoryId) return [uuid(query.categoryId, "categoryId")];
  if (!many) return null;
  const ids = [
    ...new Set(
      many
        .split(",")
        .map((id) => id.trim())
        .filter(Boolean),
    ),
  ];
  if (ids.length === 0) return null;
  if (ids.length > MAX_CATEGORY_IDS) {
    throw new BadRequestException(
      `categoryIds takes at most ${MAX_CATEGORY_IDS} categories`,
    );
  }
  return ids.map((id) => uuid(id, "categoryIds"));
}

function uuid(value: string, field: string): string {
  if (!isUUID(value)) {
    throw new BadRequestException(`${field} must be a valid UUID`);
  }
  return value;
}
