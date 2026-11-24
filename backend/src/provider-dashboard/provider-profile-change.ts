import type { City, Prisma, Provider, ProviderCategory, ProviderProfileChange } from '@prisma/client';
import type { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import type { MediaStoragePort } from '../modules/media/public/media-storage.port';
import {
  mergeProfileChange,
  profileChangeFields,
  profileChangeMediaTarget,
  type ProfileChangeFields,
} from '../modules/marketplace/public/provider-profile-change';
import * as profileChangeStore from '../modules/marketplace/infrastructure/provider-profile-change.repository';

/**
 * RA-BE-152 (Q-39 (أ), D124): an approved provider's new name, logo,
 * cover, city or category is held as his profile change; the listing keeps
 * its live values and images until the team approves in the back office.
 * The caller holds the provider's row lock and checked the city and
 * category active.
 */
export async function holdReviewedProfileFields(
  tx: Prisma.TransactionClient,
  media: MediaStoragePort,
  currentUser: AuthenticatedUser,
  provider: Provider,
  asked: Partial<ProfileChangeFields>,
  at: Date,
): Promise<void> {
  const current = await profileChangeStore.findPendingProfileChange(tx, provider.id);
  const next = mergeProfileChange(
    profileChangeFields(provider),
    current ? profileChangeFields(current) : null,
    asked,
  );
  const saved = await profileChangeStore.savePendingProfileChange(
    tx,
    provider.id,
    current,
    next,
    at,
  );
  await movePendingImages(tx, media, currentUser, current, saved);
}

/** «اسحب التعديل»: his waiting change goes, and the images it held with it. */
export async function withdrawProfileChange(
  tx: Prisma.TransactionClient,
  media: MediaStoragePort,
  currentUser: AuthenticatedUser,
  providerId: string,
  at: Date,
): Promise<boolean> {
  const current = await profileChangeStore.findPendingProfileChange(tx, providerId);
  if (!current) return false;
  await profileChangeStore.closePendingProfileChange(
    tx,
    current.id,
    profileChangeStore.withdrawal(at),
  );
  await movePendingImages(tx, media, currentUser, current, null);
  return true;
}

/**
 * The request's images follow its fields: an image it no longer asks for
 * is deleted, a newly asked one is held by the request's media target.
 */
async function movePendingImages(
  tx: Prisma.TransactionClient,
  media: MediaStoragePort,
  currentUser: AuthenticatedUser,
  before: ProviderProfileChange | null,
  after: ProviderProfileChange | null,
): Promise<void> {
  for (const image of ['logo', 'cover'] as const) {
    const field = image === 'logo' ? 'logoUrl' : 'coverUrl';
    const was = before?.[field] ?? null;
    const now = after?.[field] ?? null;
    if (was === now) continue;
    if (before && was) {
      await media.scheduleTargetDeletion(profileChangeMediaTarget(before.id, image), tx);
    }
    if (after && now) {
      await media.consumePublicMediaUrl(
        currentUser,
        now,
        image === 'logo' ? 'provider-logo' : 'provider-cover',
        profileChangeMediaTarget(after.id, image),
        tx,
      );
    }
  }
}

export type PendingProfileChange = ProviderProfileChange & {
  city: City | null;
  primaryCategory: ProviderCategory | null;
};

/** p35's «قيد المراجعة»: what he asked for, waiting for the team. */
export function toPendingProfileChangeResponse(change: PendingProfileChange | null) {
  if (!change) return null;
  return {
    id: change.id,
    businessName: change.businessName,
    cityId: change.cityId,
    city: change.city ? { id: change.city.id, nameAr: change.city.nameAr } : null,
    primaryCategoryId: change.primaryCategoryId,
    primaryCategory: change.primaryCategory
      ? { id: change.primaryCategory.id, nameAr: change.primaryCategory.nameAr }
      : null,
    logoUrl: change.logoUrl,
    coverUrl: change.coverUrl,
    createdAt: change.createdAt,
    updatedAt: change.updatedAt,
  };
}
