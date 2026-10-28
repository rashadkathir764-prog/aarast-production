import { ConflictException } from '@nestjs/common';
import { PortfolioItemStatus, Prisma } from '@prisma/client';
import type { PortfolioItem, Provider } from '@prisma/client';
import type { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import type { CatalogReadPort } from '../modules/catalog/public/catalog-read.port';
import type { MediaStoragePort } from '../modules/media/public/media-storage.port';
import {
  normalizePortfolioItems,
  normalizeSocialLinks,
  PORTFOLIO_MAX_ITEMS,
  portfolioItemNeedsReview,
  readSocialLinks,
  WOMEN_ALBUM,
} from '../modules/marketplace/public/provider-portfolio';
import * as portfolioStore from '../modules/marketplace/infrastructure/portfolio.repository';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import type { PrismaService } from '../platform/database/prisma.service';
import type { UpdateProviderPortfolioDto } from './dto/update-provider-portfolio.dto';
import { lockOwnedProviderForMutationInTransaction } from './provider-mutation-locks';

const PURPOSE = 'provider-portfolio' as const;

export interface ProviderPortfolioDependencies {
  prisma: PrismaService;
  mediaStorage: MediaStoragePort;
  catalog: CatalogReadPort;
}

/** He serves women when one of his sections is shown to brides (D62). */
export async function providerServesWomen(
  client: Prisma.TransactionClient,
  catalog: CatalogReadPort,
  provider: Pick<Provider, 'id' | 'primaryCategoryId'>,
): Promise<boolean> {
  const ids = await portfolioStore.providerCategoryIds(client, provider);
  if (ids.length === 0) return false;
  const categories = await catalog.getCategories(client, ids);
  return categories.some((category) => category.isActive && category.showForBride);
}

/** p37 as the provider reads it: every photo with its state, and his links. */
export function toOwnerPortfolioResponse(
  items: readonly PortfolioItem[],
  socialLinks: unknown,
  servesWomen: boolean,
) {
  return {
    items: items.map((item) => ({
      id: item.id,
      key: item.mediaKey,
      // A refused photo's image is deleted; its reason stays until he removes it.
      imageUrl: item.status === PortfolioItemStatus.REJECTED ? null : item.imageUrl,
      album: item.album,
      forWomen: item.forWomen,
      noFaces: item.noFaces,
      status: item.status,
      rejectionReason: item.rejectionReason,
      reviewedAt: item.reviewedAt,
      createdAt: item.createdAt,
    })),
    socialLinks: readSocialLinks(socialLinks),
    servesWomen,
    womenAlbum: WOMEN_ALBUM,
    maxItems: PORTFOLIO_MAX_ITEMS,
  };
}

/**
 * B-16 (D62): the provider's «معرض الشغل». Only an approved provider (D41:
 * photos after approval) writes it. A new photo is a verified
 * `provider-portfolio` upload of his, consumed by its item; it waits for
 * review. A kept photo keeps its decision unless its album or «بدون وجوه»
 * changed. A removed photo's image is deleted by the media cleanup.
 */
export class ProviderPortfolio {
  constructor(private readonly deps: ProviderPortfolioDependencies) {}

  async get(provider: Provider) {
    const [items, servesWomen] = await Promise.all([
      portfolioStore.listProviderPortfolio(this.deps.prisma, provider.id),
      providerServesWomen(this.deps.prisma, this.deps.catalog, provider),
    ]);
    return toOwnerPortfolioResponse(items, provider.socialLinks, servesWomen);
  }

  async replace(currentUser: AuthenticatedUser, dto: UpdateProviderPortfolioDto) {
    // The list's shape and the links are checked before anything is read.
    normalizePortfolioItems(dto.items, true);
    const socialLinks = dto.socialLinks === undefined ? undefined : normalizeSocialLinks(dto.socialLinks);

    // New photos are verified against storage outside the transaction.
    const known = new Set(
      await portfolioStore.listPortfolioKeysOfOwner(this.deps.prisma, currentUser.id),
    );
    const verifiedUrls = new Map<string, string>();
    for (const item of dto.items) {
      const key = item.key.trim();
      if (known.has(key) || verifiedUrls.has(key)) continue;
      const verified = await this.deps.mediaStorage.verifyUpload(currentUser, key, PURPOSE);
      verifiedUrls.set(key, verified.publicUrl!);
    }

    return runSerializableTransaction(this.deps.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
        'UPDATE',
      );
      const servesWomen = await providerServesWomen(tx, this.deps.catalog, provider);
      const items = normalizePortfolioItems(dto.items, servesWomen);
      const stored = await portfolioStore.listProviderPortfolio(tx, provider.id);
      const byKey = new Map(stored.map((item) => [item.mediaKey, item]));
      const wanted = new Set(items.map((item) => item.key));

      const write: portfolioStore.PortfolioWrite = { create: [], update: [], removeIds: [] };
      for (const item of items) {
        const current = byKey.get(item.key);
        if (current) {
          write.update.push({
            id: current.id,
            album: item.album,
            forWomen: item.forWomen,
            noFaces: item.noFaces,
            sortOrder: item.sortOrder,
            reset: portfolioItemNeedsReview(current, item),
          });
          continue;
        }
        const imageUrl = verifiedUrls.get(item.key);
        if (!imageUrl) {
          // Removed by another request after this one read the list.
          throw new ConflictException({
            code: 'PORTFOLIO_CHANGED',
            message: 'The portfolio changed meanwhile; read it and send it again',
          });
        }
        write.create.push({
          mediaKey: item.key,
          imageUrl,
          album: item.album,
          forWomen: item.forWomen,
          noFaces: item.noFaces,
          sortOrder: item.sortOrder,
        });
      }
      for (const item of stored) {
        if (wanted.has(item.mediaKey)) continue;
        write.removeIds.push(item.id);
        await this.deps.mediaStorage.scheduleTargetDeletion({ type: 'PORTFOLIO_ITEM', id: item.id }, tx);
      }

      const links =
        socialLinks === undefined
          ? (provider.socialLinks as Prisma.InputJsonValue | null) ?? Prisma.DbNull
          : Object.keys(socialLinks).length > 0
            ? (socialLinks as Prisma.InputJsonValue)
            : Prisma.DbNull;
      const createdIds = await portfolioStore.writeProviderPortfolio(tx, provider.id, write, links);
      for (const [index, id] of createdIds.entries()) {
        await this.deps.mediaStorage.consumeUpload(
          currentUser,
          write.create[index].mediaKey,
          PURPOSE,
          { type: 'PORTFOLIO_ITEM', id },
          tx,
        );
      }

      const after = await portfolioStore.listProviderPortfolio(tx, provider.id);
      const linksAfter = socialLinks === undefined ? provider.socialLinks : socialLinks;
      return toOwnerPortfolioResponse(after, linksAfter, servesWomen);
    });
  }
}
