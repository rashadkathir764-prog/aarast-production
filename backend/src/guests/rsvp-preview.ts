/**
 * 6a: what a link crawler (WhatsApp's preview) reads of one guest's RSVP
 * link, without running the page's script. The public site keeps the one
 * page (deploy/public-site/rsvp.html) and includes this fragment in its head
 * through nginx SSI; a dead link answers nothing and the page keeps its
 * generic tags.
 */
export interface RsvpPreview {
  title: string;
  description: string;
  /** The link itself, on the public origin. */
  url: string;
  /** اعّرست's own mark. RA-OP-29: never the invitation card's photo. */
  image: { url: string; type: string | null } | null;
}

/** The public site's copy of اعّرست's launcher icon (deploy/public-site). */
export const RSVP_PREVIEW_LOGO_PATH = "/rsvp-preview.png";

function escapeAttribute(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function meta(attribute: "property" | "name", key: string, value: string): string {
  return `<meta ${attribute}="${key}" content="${escapeAttribute(value)}">`;
}

export function renderRsvpPreviewHead(preview: RsvpPreview): string {
  return [
    meta("property", "og:title", preview.title),
    meta("property", "og:description", preview.description),
    meta("property", "og:url", preview.url),
    ...(preview.image
      ? [
          meta("property", "og:image", preview.image.url),
          ...(preview.image.type
            ? [meta("property", "og:image:type", preview.image.type)]
            : []),
          meta("property", "og:image:alt", preview.title),
        ]
      : []),
    // A square mark, not a photo: the small card.
    meta("name", "twitter:card", "summary"),
  ].join("\n");
}
