import { Prisma } from '@prisma/client';
import { MONEY_STARTER_CATALOG_KEY } from '../../../catalogs/reference-catalog.defaults';
import type {
  MoneyCatalogItem,
  MoneyCatalogPersona,
} from '../public/catalog-read.port';

const PERSONAS: ReadonlySet<string> = new Set(['GROOM', 'BRIDE', 'NEUTRAL']);

/**
 * The published, active items of the money catalog in the catalog's order,
 * each with its persona and the provider categories the owner linked it to
 * (D73). An inactive catalog offers nothing.
 */
export async function listPublishedMoneyCatalogItems(
  client: Prisma.TransactionClient,
): Promise<MoneyCatalogItem[]> {
  const catalog = await client.referenceCatalog.findUnique({
    where: { key: MONEY_STARTER_CATALOG_KEY },
    include: {
      items: {
        where: { publishedRevision: { gt: 0 } },
        include: { revisions: true },
      },
    },
  });
  if (!catalog?.isActive) return [];
  return catalog.items
    .flatMap((item) => {
      const revision = item.revisions.find(
        (candidate) => candidate.revision === item.publishedRevision,
      );
      return revision?.isActive ? [revision] : [];
    })
    .sort(
      (left, right) =>
        left.sortOrder - right.sortOrder ||
        left.nameAr.localeCompare(right.nameAr, 'ar'),
    )
    .map((revision) => {
      const metadata = metadataRecord(revision.metadata);
      const persona = metadata?.persona;
      return {
        nameAr: revision.nameAr,
        persona:
          typeof persona === 'string' && PERSONAS.has(persona)
            ? (persona as MoneyCatalogPersona)
            : null,
        showForGroom: revision.showForGroom,
        showForBride: revision.showForBride,
        providerCategorySlugs: providerCategorySlugsOf(metadata),
      };
    });
}

/**
 * `metadata.providerCategorySlugs` as the catalog stores it: the write path
 * accepts only a list of slugs, so anything else here is a row written
 * before D73 and reads as no link.
 */
function providerCategorySlugsOf(
  metadata: Record<string, Prisma.JsonValue> | null,
): string[] {
  const value = metadata?.providerCategorySlugs;
  if (!Array.isArray(value)) return [];
  const slugs = value.flatMap((slug) =>
    typeof slug === 'string' && slug.trim() !== '' ? [slug.trim()] : [],
  );
  return [...new Set(slugs)];
}

function metadataRecord(
  metadata: Prisma.JsonValue | null | undefined,
): Record<string, Prisma.JsonValue> | null {
  return metadata && typeof metadata === 'object' && !Array.isArray(metadata)
    ? (metadata as Record<string, Prisma.JsonValue>)
    : null;
}
