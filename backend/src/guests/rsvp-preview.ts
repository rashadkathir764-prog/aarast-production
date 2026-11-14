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
  /** The card photo through the link's own route, when the card has one. */
  image: { url: string; type: string | null } | null;
}

const IMAGE_TYPES: Record<string, string> = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
};

/** The stored photo's media type, from the extension the upload gave it. */
export function imageTypeOf(storedUrl: string): string | null {
  const extension = /\.([a-z0-9]+)$/i.exec(new URL(storedUrl).pathname)?.[1];
  return extension ? (IMAGE_TYPES[extension.toLowerCase()] ?? null) : null;
}

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
    meta(
      "name",
      "twitter:card",
      preview.image ? "summary_large_image" : "summary",
    ),
  ].join("\n");
}
