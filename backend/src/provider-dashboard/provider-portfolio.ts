import { ConflictException } from '@nestjs/common';
import { PortfolioItemStatus, Prisma } from '@prisma/client';
import type { PortfolioItem, Provider } from '@prisma/client';
import type { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import type { CatalogReadPort } from '../modules/catalog/public/catalog-read.port';
import type { MediaStoragePort } from '../modules/media/public/media-storage.port';
import {
  APPLICATION_MIN_PHOTOS,
  isProviderAwaitingApproval,
  providerPhotosRequired,
} from '../modules/marketplace/public/provider-review';
import { hasApplicationPhotos } from '../modules/marketplace/infrastructure/provider-review.repository';
import {
  normalizePortfolioItems,
  normalizeSocialLinks,
  PORTFOLIO_MAX_ITEMS,
  portfolioItemNeedsReview,
  readSocialLinks,
  splitPortfolioRemovals,
  WOMEN_ALBUM,
} from '../modules/marketplace/public/provider-portfolio';
import * as portfolioStore from '../modules/marketplace/infrastructure/portfolio.repository';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import type { PrismaService } from '../platform/database/prisma.service';
import type { UpdateProviderPortfolioDto } from './dto/update-provider-portfolio.dto';
import { lockOwnedProviderForMutationInTransaction } from './provider-mutation-locks';

const PURPOSE = 'provider-portfolio' as const;

/** The photos an application counts: waiting or approved, never refused. */
function countedPhotos(items: readonly Pick<PortfolioItem, 'status'>[]): number {
  return items.filter((item) => item.status !== PortfolioItemStatus.REJECTED).length;
}

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
 * B-16 (D62): the provider's «معرض الشغل». An approved provider writes it,
 * and so does one waiting for approval: his application goes to review with
 * {@link APPLICATION_MIN_PHOTOS} photos (Q-59, D127), which he keeps while
 * he waits. A new photo is a verified `provider-portfolio` upload of his,
 * consumed by its item; it waits for review, and customers see it only once
 * his profile is approved too. A kept photo keeps its decision unless its
 * album or «بدون وجوه» changed. A removed photo's image is deleted by the
 * media cleanup.
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

  /**
   * Q-59: the application's photos, checked and verified against storage
   * before its transaction: fewer than {@link APPLICATION_MIN_PHOTOS} is
   * refused before any upload is read. The women's album is checked again
   * once the profile exists ({@link attachToApplication}).
   */
  async verifyApplicationPhotos(
    currentUser: AuthenticatedUser,
    items: UpdateProviderPortfolioDto['items'] | undefined,
  ): Promise<Map<string, string>> {
    const photos = normalizePortfolioItems(items ?? [], true);
    if (photos.length < APPLICATION_MIN_PHOTOS) throw providerPhotosRequired();
    return this.verifyNewUploads(currentUser, photos.map((photo) => photo.key), new Set());
  }

  /**
   * Q-59: the application's photos join the profile it just created, in its
   * transaction, each waiting for the team's review.
   */
  async attachToApplication(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    provider: Pick<Provider, 'id' | 'primaryCategoryId'>,
    items: UpdateProviderPortfolioDto['items'],
    verifiedUrls: ReadonlyMap<string, string>,
  ): Promise<void> {
    const servesWomen = await providerServesWomen(tx, this.deps.catalog, provider);
    const write: portfolioStore.PortfolioWrite = { create: [], update: [], removeIds: [] };
    for (const item of normalizePortfolioItems(items, servesWomen)) {
      write.create.push({
        mediaKey: item.key,
        imageUrl: verifiedUrls.get(item.key)!,
        album: item.album,
        forWomen: item.forWomen,
        noFaces: item.noFaces,
        sortOrder: item.sortOrder,
      });
    }
    const createdIds = await portfolioStore.writeProviderPortfolio(
      tx,
      provider.id,
      write,
      Prisma.DbNull,
    );
    await this.consumeCreated(tx, currentUser, write, createdIds);
  }

  /** Q-59: whether the profile has the photos its review needs. */
  hasApplicationPhotos(tx: Prisma.TransactionClient, providerId: string): Promise<boolean> {
    return hasApplicationPhotos(tx, providerId);
  }

  async replace(currentUser: AuthenticatedUser, dto: UpdateProviderPortfolioDto) {
    // The list's shape and the links are checked before anything is read.
    normalizePortfolioItems(dto.items, true);
    const socialLinks = dto.socialLinks === undefined ? undefined : normalizeSocialLinks(dto.socialLinks);

    // New photos are verified against storage outside the transaction.
    const verifiedUrls = await this.verifyNewUploads(
      currentUser,
      dto.items.map((item) => item.key.trim()),
      new Set(await portfolioStore.listPortfolioKeysOfOwner(this.deps.prisma, currentUser.id)),
    );

    return runSerializableTransaction(this.deps.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'PORTFOLIO',
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
      // RA-MO-287: a photo this save never saw (added from his other phone
      // after this list was read) is kept, after the list he sent.
      const { remove, unseen } = splitPortfolioRemovals(
        stored.map((item) => item.mediaKey),
        wanted,
        dto.knownKeys,
      );
      // Q-59: while the team has his application, a photo it counts may go
      // only when three stay; adding is always open, so a profile from
      // before the rule reaches them one photo at a time.
      if (isProviderAwaitingApproval(provider)) {
        const removing = new Set(remove);
        const before = countedPhotos(stored);
        const after =
          countedPhotos(stored.filter((item) => !removing.has(item.mediaKey))) +
          write.create.length;
        if (after < APPLICATION_MIN_PHOTOS && after < before) {
          throw providerPhotosRequired();
        }
      }
      for (const key of remove) {
        const item = byKey.get(key)!;
        write.removeIds.push(item.id);
        await this.deps.mediaStorage.scheduleTargetDeletion({ type: 'PORTFOLIO_ITEM', id: item.id }, tx);
      }
      for (const [index, key] of unseen.entries()) {
        const item = byKey.get(key)!;
        write.update.push({
          id: item.id,
          album: item.album,
          forWomen: item.forWomen,
          noFaces: item.noFaces,
          sortOrder: items.length + index,
          reset: false,
        });
      }

      const links =
        socialLinks === undefined
          ? (provider.socialLinks as Prisma.InputJsonValue | null) ?? Prisma.DbNull
          : Object.keys(socialLinks).length > 0
            ? (socialLinks as Prisma.InputJsonValue)
            : Prisma.DbNull;
      const createdIds = await portfolioStore.writeProviderPortfolio(tx, provider.id, write, links);
      await this.consumeCreated(tx, currentUser, write, createdIds);

      const after = await portfolioStore.listProviderPortfolio(tx, provider.id);
      const linksAfter = socialLinks === undefined ? provider.socialLinks : socialLinks;
      return toOwnerPortfolioResponse(after, linksAfter, servesWomen);
    });
  }

  /** Each new key verified as his `provider-portfolio` upload, once; [known] keys are his already. */
  private async verifyNewUploads(
    currentUser: AuthenticatedUser,
    keys: readonly string[],
    known: ReadonlySet<string>,
  ): Promise<Map<string, string>> {
    const verifiedUrls = new Map<string, string>();
    for (const key of keys) {
      if (known.has(key) || verifiedUrls.has(key)) continue;
      const verified = await this.deps.mediaStorage.verifyUpload(currentUser, key, PURPOSE);
      verifiedUrls.set(key, verified.publicUrl!);
    }
    return verifiedUrls;
  }

  /** Each created photo consumes its upload. */
  private async consumeCreated(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    write: portfolioStore.PortfolioWrite,
    createdIds: readonly string[],
  ): Promise<void> {
    for (const [index, id] of createdIds.entries()) {
      await this.deps.mediaStorage.consumeUpload(
        currentUser,
        write.create[index].mediaKey,
        PURPOSE,
        { type: 'PORTFOLIO_ITEM', id },
        tx,
      );
    }
  }
}
