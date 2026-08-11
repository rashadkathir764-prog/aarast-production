# Aarast Visual Approval Prototypes — 2026 Direction

Status: design approval gate only. These files are not Flutter implementation.

## Direction

`ديوان العرس المعاصر`: Arabic editorial wedding warmth over a precise,
trustworthy financial product. The current Home remains the identity anchor;
these prototypes test how that identity can become less card-heavy and more
distinct across operational surfaces.

## Screens

- `money-v1.html`: Money overview using only the canonical budget, category,
  cost, payment, and payment-date concepts.
- `guests-v1.html`: Guest overview and list with an honest five-seat sample
  derived from three invitations, including two companions.
- `provider-v1.html`: Provider details with quote-only language. It intentionally
  contains no booking, deposit, payment, or open-chat action.

Each screen is designed for a `390 × 844` RTL viewport and includes a `320px`
fallback rule. The numbers and people shown are presentation fixtures only;
production implementation must bind to real models and permissions.

## Generated Image

`provider-venue-hero.png` was generated specifically for this design prototype
with the built-in image-generation workflow. Prompt intent: an original,
photorealistic contemporary Arabic wedding venue in ivory, pomegranate
burgundy, charcoal, and restrained antique gold; no people, text, logos,
watermarks, booking, or payment symbolism.

Final prompt:

```text
Use case: photorealistic-natural
Asset type: wide hero photograph for a premium Arabic wedding-provider detail
screen prototype
Primary request: an original contemporary luxury wedding reception hall
suitable for a Yemen-first Arabic wedding planning product
Scene: refined indoor hall with warm ivory limestone, sculptural Arabic arches,
soft burgundy velvet accents, restrained brushed-gold details, elegant round
tables, and minimal white florals
Style: photorealistic editorial interior photography with believable materials
Composition: wide, eye-level architectural depth with calm negative space for a
UI gradient overlay
Lighting: warm late-afternoon window light mixed with soft candlelight
Constraints: no text, logos, watermark, people, booking, or payment symbolism
Avoid: gaudy palace excess, excessive gold, neon, Western church cues, fantasy
architecture, plastic surfaces, oversaturation, and a stock-photo look
```

## Approval Rule

Do not migrate these designs into Flutter until the user explicitly approves
the visual direction. Approval of a screenshot is not approval of new product
behavior; routes, APIs, permissions, privacy, and data contracts remain
unchanged unless separately authorized.
