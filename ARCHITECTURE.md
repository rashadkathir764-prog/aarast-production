# Aarast Modular Monolith Architecture

[ARCHITECTURE_CONSTITUTION.md](ARCHITECTURE_CONSTITUTION.md) states the binding laws. This file is the working map.

## Business Module Map

Aarast has these 13 business modules and no others.

| Module | Current roots | Owns |
| --- | --- | --- |
| identity | auth, users, me, contexts | identity/session models |
| planning | wedding-plans, onboarding | WeddingPlan, PlanEvent |
| finance | money, budget-categories, wedding-costs | budget/cost/payment/schedule/funding models |
| collaboration | sharing, contribution-history | sharing and contribution-history models |
| tasks | tasks | task and checklist models |
| guests | guests | guest and guest-group models |
| marketplace | marketplace, provider-dashboard | provider, review, quote, favorite, and plan-provider models |
| messaging | conversations | conversation, event, message, attachment, and report models |
| notifications | notifications, push | notification, preference, and push-installation models |
| catalog | catalogs | geography, provider category, and reference-catalog models |
| media | media | MediaUploadTicket |
| insights | dashboard, timeline | no models; read composition only |
| backoffice | admin | AdminAuditLog |

Platform owns `IdempotencyKey` and `OutboxEvent`. Platform is infrastructure, not a business module. `shared-kernel` is a layer, not a business module. A context is the union of its root folder and `src/modules/<context>`.

## Dependency Direction

```text
business modules -> platform -> shared-kernel
```

Business modules may also import `shared-kernel` directly. `platform` may not import business modules, and `shared-kernel` may import neither `platform` nor business modules.

Every cross-context edge targets the owner's `public/` slice. The Nest class and import graph stays acyclic and `forwardRef()` is forbidden.

## Nest Module Binding Pattern

```typescript
@Module({ providers: [NameService], exports: [NameService] })
export class NameInternalModule {}

@Module({
  imports: [NameInternalModule],
  providers: [{ provide: NAME_PORT, useExisting: NameService }],
  exports: [NAME_PORT],
})
export class NamePublicModule {}

@Module({
  imports: [NameInternalModule, NamePublicModule],
  controllers: [NameController],
})
export class NameModule {}
```

- `InternalModule` is private to its owning context.
- `PublicModule` exports Symbol tokens and public types only.
- A full module may import another context's `PublicModule`, never its full or internal module.
- Cross-context consumers depend on the owner's public token and types.

## Physical Data Ownership

Every Prisma model has one physical owner. Ownership covers root delegates, relation traversal, nested writes, and every table referenced by raw SQL.

A transaction that spans contexts keeps the caller's transaction boundary through an explicit owner public port; it does not transfer ownership to the caller.

`architecture:ownership` fails on any foreign access, including an argument shape it cannot prove, so product code declares the exact `where` and `data` shapes it passes. Consumers that present another owner's rows attach them after their own read through the owners' ports. Every `domain/` is free of `@nestjs/*`, runtime Prisma and the persistence layer.

## Mobile Boundary Contract

- Cross-feature imports target `<feature>_api.dart`.
- `core/** -> features/**` imports are forbidden, except route assembly under `core/routing/**`, which may import feature public barrels.
- `part` files stay inside the same feature or core area. Cross-area parts and unresolved local directives fail immediately.
- A library may keep private widgets, route trees or flows in `<file>.<topic>.dart` parts.

## Gates

The `backend/architecture/*.json` manifests, `backend/scripts/architecture/`, `scripts/architecture/` and the `architecture-*` tests are live gates, whatever their names. They guard the boundaries above. Do not weaken them.
