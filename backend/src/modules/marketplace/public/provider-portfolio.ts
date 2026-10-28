import { BadRequestException, UnprocessableEntityException } from '@nestjs/common';
import { PortfolioItemStatus } from '@prisma/client';

/**
 * B-16 (D62): «معرض الشغل» (p37). The provider sends his whole portfolio at
 * once (`PUT /api/v1/provider/me/portfolio`): the photos in their order, each
 * with its album and his «بدون وجوه», and his TikTok, Instagram and Facebook
 * links. Every new photo is PENDING until the moderation team approves it
 * (n07); customers see only APPROVED photos. The women's album
 * «حفلات النساء» is shown to brides only, takes only photos the provider
 * confirmed show no faces, and exists only for a provider who serves women
 * (one of his sections is shown to brides).
 */
export const WOMEN_ALBUM = 'حفلات النساء';
/** Photos one provider keeps, refused ones included until he removes them. */
export const PORTFOLIO_MAX_ITEMS = 60;
export const PORTFOLIO_ALBUM_MAX_LENGTH = 30;
export const PORTFOLIO_REJECTION_REASON_MAX_LENGTH = 300;

export type SocialNetwork = 'tiktok' | 'instagram' | 'facebook';
export type SocialLinks = Partial<Record<SocialNetwork, string>>;
export const SOCIAL_NETWORKS: readonly SocialNetwork[] = ['tiktok', 'instagram', 'facebook'];

const HOSTS: Record<SocialNetwork, readonly string[]> = {
  tiktok: ['tiktok.com', 'www.tiktok.com', 'm.tiktok.com'],
  instagram: ['instagram.com', 'www.instagram.com', 'm.instagram.com'],
  facebook: ['facebook.com', 'www.facebook.com', 'm.facebook.com', 'web.facebook.com'],
};

/** Paths that are pages of the network itself, never someone's profile. */
const RESERVED: Record<SocialNetwork, ReadonlySet<string>> = {
  tiktok: new Set(),
  instagram: new Set(['p', 'reel', 'reels', 'explore', 'stories', 'accounts', 'direct', 'tv']),
  facebook: new Set([
    'groups', 'events', 'watch', 'marketplace', 'pages', 'login', 'sharer',
    'share', 'story.php', 'photo.php', 'permalink.php', 'help', 'policies',
  ]),
};

function invalidLink(network: SocialNetwork): never {
  throw new UnprocessableEntityException({
    code: 'PORTFOLIO_SOCIAL_LINK_INVALID',
    network,
    message: `The ${network} link must be an https profile address on ${network}`,
  });
}

/**
 * One profile link, checked and written in one form: https, the network's
 * own host, a profile path (TikTok `/@name`, Instagram `/name`, Facebook
 * `/name` or `/profile.php?id=digits`), no user, port or fragment.
 */
export function normalizeSocialLink(network: SocialNetwork, value: string): string {
  const raw = value.trim();
  if (raw.length === 0 || raw.length > 200) invalidLink(network);
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    invalidLink(network);
  }
  const host = url.hostname.toLowerCase();
  if (
    url.protocol !== 'https:' ||
    url.username !== '' ||
    url.password !== '' ||
    url.port !== '' ||
    url.hash !== '' ||
    !HOSTS[network].includes(host)
  ) {
    invalidLink(network);
  }
  const segments = url.pathname.split('/').filter((segment) => segment.length > 0);
  if (segments.length !== 1) invalidLink(network);
  const [segment] = segments;
  if (RESERVED[network].has(segment.toLowerCase())) invalidLink(network);

  if (network === 'tiktok') {
    if (url.search !== '' || !/^@[A-Za-z0-9._]{2,24}$/.test(segment)) invalidLink(network);
    return `https://www.tiktok.com/${segment}`;
  }
  if (network === 'instagram') {
    if (url.search !== '' || !/^[A-Za-z0-9._]{1,30}$/.test(segment)) invalidLink(network);
    return `https://www.instagram.com/${segment}`;
  }
  if (segment === 'profile.php') {
    const id = url.searchParams.get('id') ?? '';
    if ([...url.searchParams.keys()].length !== 1 || !/^[0-9]{5,20}$/.test(id)) {
      invalidLink(network);
    }
    return `https://www.facebook.com/profile.php?id=${id}`;
  }
  if (url.search !== '' || !/^[A-Za-z0-9.]{5,50}$/.test(segment)) invalidLink(network);
  return `https://www.facebook.com/${segment}`;
}

/** The links the provider sent, each checked; an empty one is removed. */
export function normalizeSocialLinks(
  input: Partial<Record<SocialNetwork, string | null>> | null | undefined,
): SocialLinks {
  const links: SocialLinks = {};
  for (const network of SOCIAL_NETWORKS) {
    const value = input?.[network];
    if (value == null || value.trim() === '') continue;
    links[network] = normalizeSocialLink(network, value);
  }
  return links;
}

/** The stored links as the app reads them (anything else stored is ignored). */
export function readSocialLinks(value: unknown): SocialLinks {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const links: SocialLinks = {};
  for (const network of SOCIAL_NETWORKS) {
    const link = (value as Record<string, unknown>)[network];
    if (typeof link === 'string' && link.length > 0) links[network] = link;
  }
  return links;
}

export interface PortfolioItemInput {
  key: string;
  album?: string | null;
  noFaces?: boolean;
}

export interface NormalizedPortfolioItem {
  key: string;
  album: string | null;
  forWomen: boolean;
  noFaces: boolean;
  sortOrder: number;
}

/**
 * The provider's list, checked: at most {@link PORTFOLIO_MAX_ITEMS} photos,
 * each once; an album is a short label; the women's album needs a provider
 * who serves women and the provider's «بدون وجوه» on every photo in it.
 */
export function normalizePortfolioItems(
  items: readonly PortfolioItemInput[],
  servesWomen: boolean,
): NormalizedPortfolioItem[] {
  if (items.length > PORTFOLIO_MAX_ITEMS) {
    throw new UnprocessableEntityException({
      code: 'PORTFOLIO_TOO_MANY_ITEMS',
      max: PORTFOLIO_MAX_ITEMS,
      message: `A portfolio holds at most ${PORTFOLIO_MAX_ITEMS} photos`,
    });
  }
  const seen = new Set<string>();
  return items.map((item, index) => {
    const key = item.key.trim();
    if (seen.has(key)) {
      throw new BadRequestException('Each portfolio photo may be listed once');
    }
    seen.add(key);
    const album = item.album?.trim().replace(/\s+/g, ' ') || null;
    if (album && album.length > PORTFOLIO_ALBUM_MAX_LENGTH) {
      throw new BadRequestException(
        `An album name has at most ${PORTFOLIO_ALBUM_MAX_LENGTH} characters`,
      );
    }
    const forWomen = album === WOMEN_ALBUM;
    const noFaces = item.noFaces === true;
    if (forWomen && !servesWomen) {
      throw new UnprocessableEntityException({
        code: 'PORTFOLIO_WOMEN_ALBUM_NOT_SERVED',
        message: 'Only a provider who serves women has the women\'s album',
      });
    }
    if (forWomen && !noFaces) {
      throw new UnprocessableEntityException({
        code: 'PORTFOLIO_WOMEN_PHOTO_NEEDS_NO_FACES',
        message: 'A photo in the women\'s album must show no faces',
      });
    }
    return { key, album, forWomen, noFaces, sortOrder: index };
  });
}

/** A photo kept as it was, or changed so that it is reviewed again. */
export function portfolioItemNeedsReview(
  stored: { album: string | null; noFaces: boolean; status: PortfolioItemStatus },
  next: { album: string | null; noFaces: boolean },
): boolean {
  if (stored.status === PortfolioItemStatus.REJECTED) return false;
  return stored.album !== next.album || stored.noFaces !== next.noFaces;
}

/** Who may read a photo: customers the approved ones, brides also the women's album. */
export function isPortfolioItemVisibleTo(
  item: { status: PortfolioItemStatus; forWomen: boolean },
  readerIsBride: boolean,
): boolean {
  return item.status === PortfolioItemStatus.APPROVED && (!item.forWomen || readerIsBride);
}
