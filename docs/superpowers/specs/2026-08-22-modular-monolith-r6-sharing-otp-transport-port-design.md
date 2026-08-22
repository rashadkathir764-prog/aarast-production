# Modular Monolith R6 Sharing OTP Transport Port Design

**Status:** Owner-approved for planning; implementation not started

**Date:** 2026-08-22

**Immutable base:** `ce0c0d19824bff79d91417e2fe4617914c6bcd70`

## Objective

R6 removes the final migration debt explicitly deferred from R1 and R3:
`backend/src/sharing/invitation-delivery.service.ts` directly imports the
concrete OpenWA transient-text sender and its transport-specific error classes.

R6 introduces one demand-driven Identity public port and one Identity internal
adapter. Collaboration keeps ownership of invitation content, persistence,
status mapping, metrics, and privacy-safe logging. Identity owns the public
delivery capability and maps the platform-specific OpenWA result into a stable
Identity contract. The platform transport remains byte-identical.

R6 is complete only when:

- the Sharing/Collaboration source has no import of
  `platform/otp-transport/openwa-transient-text` or another concrete OTP
  transport;
- one canonical `IDENTITY_TRANSIENT_DELIVERY_PORT` exists under the Identity
  public slice and has exactly one current consumer;
- one internal adapter wraps the existing `sendOpenWaTransientText` function;
- the adapter is registered once and exposed through `useExisting`, with the
  public token and implementation resolving to the same singleton instance;
- Collaboration imports only the Identity public module and injects the exact
  TypeChecker-resolved token and interface;
- invitation message text, token validation, public origin validation,
  delivery status mapping, metrics, warning shape, error precedence, timeout,
  acknowledgement, credential rotation, and privacy behavior remain unchanged;
- dependency evidence remains exactly 31 records and ownership remains 385
  records / 781 occurrences;
- the R3 strict graph remains at 13 contexts, zero duplicates, zero platform
  debts, zero retired provider edges, zero `forwardRef()`, two approved
  globals, zero cycles, and zero illegal imports;
- schema, migrations, seed, package/lock security state, Mobile, Admin Web,
  workflows, Compose, and deployment remain frozen;
- exhaustive local gates, immutable runtime, independent review, and the owner
  phone invitation checkpoint pass before local R6 closeout.

## Current Source Truth

At immutable R6 base:

- `InvitationDeliveryService` owns the generic Arabic invitation message,
  validates the private token and HTTPS invite origin, records bounded outcome
  metrics, and persists no phone/token/message in logs;
- the service checks the existing null-phone and `AUTH_OTP_MODE` conditions
  before building the invitation message;
- it calls `sendOpenWaTransientText` directly and maps
  `OpenWaTransientDeliveryUncertainError` to `UNCERTAIN`;
- it maps `OpenWaTransientDeliveryRejectedError` and all other failures to
  `UNAVAILABLE`, while retaining distinct privacy-safe metric labels;
- `SharingService` calls the service after the invite transaction at both
  create and reissue points, then persists the mapped delivery status in a
  separate serializable transaction;
- `OpenWaOtpChannel` is the only other source consumer of the transient sender
  and remains unchanged;
- `CollaborationServicesInternalModule` already imports Identity public
  capability modules and owns the sole `InvitationDeliveryService` provider;
- the focused invitation/OpenWA tests pass 28/29 with one intentional Windows
  permission skip;
- the complete architecture and TypeScript checks are green at the R5 receipt.

This is one concrete seam. R6 is not a Collaboration source relocation, an OTP
product rewrite, or an OpenWA replacement.

## Ownership Decision

### Collaboration continues to own

- invitation token presentation and link construction;
- Arabic invitation copy;
- public invite origin policy;
- invite delivery status persistence;
- `invitationDeliveryOutcomesTotal` labels;
- privacy-safe warning events;
- create/reissue ordering and transaction boundaries.

### Identity owns

- the public transient phone-delivery capability consumed by Collaboration;
- the stable non-provider-specific delivery errors;
- the single internal adapter from that public contract to the platform
  transport;
- the public/internal Nest module pair and singleton binding.

### Platform continues to own

- OpenWA configuration and credential rotation;
- recipient normalization for the transport;
- hardened transient endpoint selection;
- bounded provider responses;
- timeout and acknowledgement semantics;
- concrete OpenWA rejected/uncertain errors;
- the existing WhatsApp and OpenWA OTP channel implementations.

This direction is deliberate. Platform does not import a business context, and
Collaboration no longer imports a concrete platform adapter. Identity exposes a
real capability with one current consumer; the public port is not speculative.

## Public Contract

The planned public contract is:

```ts
export const IDENTITY_TRANSIENT_DELIVERY_PORT = Symbol(
  'IDENTITY_TRANSIENT_DELIVERY_PORT',
);

export interface IdentityTransientDeliveryInput {
  phone: string;
  text: string;
}

export interface IdentityTransientDeliveryPort {
  deliver(input: IdentityTransientDeliveryInput): Promise<void>;
}

export class IdentityTransientDeliveryUncertainError extends Error {}
export class IdentityTransientDeliveryRejectedError extends Error {}
```

Names and declaration identity are part of the machine-checked contract. The
port does not expose OpenWA configuration, provider status codes, fetch,
credentials, OTP generation, invitation tokens, plan IDs, or database types.

The interface accepts already-composed text so Collaboration retains message
ownership. It accepts only a normalized delivery input and returns no provider
identifier or message ID. Known provider errors are translated to the two
public errors; unexpected errors remain unexpected so the current Collaboration
catch-all path still records `failed`.

## Internal Adapter

`IdentityTransientDeliveryAdapter` is a dependency-free Nest provider under
the Identity internal slice. Its only production dependency is the existing
platform transient sender.

It must:

1. call `sendOpenWaTransientText(input)` exactly once;
2. translate only the concrete uncertain and rejected errors into their exact
   Identity public equivalents;
3. rethrow every other error unchanged;
4. never log, persist, copy, decorate, retry, or modify the phone or text;
5. never read Prisma, open a transaction, generate an OTP, select a route, or
   alter provider configuration.

The adapter is registered as a concrete class and aliased to
`IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION` with `useExisting`. The public
module aliases `IDENTITY_TRANSIENT_DELIVERY_PORT` to that implementation with
`useExisting`. `useClass`, duplicate concrete registration, factory-created
instances, and compatibility aliases are forbidden.

## Nest Module Shape

```text
IdentityModule
  imports IdentityTransientDeliveryPublicModule

IdentityTransientDeliveryPublicModule
  imports IdentityTransientDeliveryInternalModule
  provides IDENTITY_TRANSIENT_DELIVERY_PORT
    useExisting IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION
  exports IDENTITY_TRANSIENT_DELIVERY_PORT

IdentityTransientDeliveryInternalModule
  provides IdentityTransientDeliveryAdapter
  provides IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION
    useExisting IdentityTransientDeliveryAdapter
  exports IdentityTransientDeliveryAdapter
  exports IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION

CollaborationServicesInternalModule
  imports IdentityTransientDeliveryPublicModule
  provides InvitationDeliveryService
```

Both the Identity full module and Collaboration import the same static public
module class. Nest therefore reuses the same module token and provider instance.
No module is global and no `forwardRef()` is introduced.

## Exact Behavioral Preservation

The current observable sequence remains:

1. If phone is absent, or `AUTH_OTP_MODE` is not `openwa`, return
   `{ channel: 'WHATSAPP', status: 'UNAVAILABLE' }`, increment
   `not_attempted`, and do not validate or render the token.
2. Validate the token and public HTTPS origin only when delivery is attempted.
3. Build the exact same Arabic message.
4. Call the injected Identity port once with the same phone and text.
5. On success, increment `delivered` and return `DELIVERED`.
6. On the public uncertain error, increment `uncertain`, emit the same safe
   warning, and return `UNCERTAIN`.
7. On the public rejected error, increment `rejected`, emit the same safe
   warning, and return `UNAVAILABLE`.
8. On every other error, increment `failed`, emit the same safe warning, and
   return `UNAVAILABLE`.

The adapter boundary may not move token validation ahead of the current
availability check, because that would change error precedence for disabled
delivery. It may not return a false success or turn an uncertain result into a
rejection.

## Test Policy

Existing behavioral assertions, fixtures, expected values, privacy checks,
Arabic copy, URLs, request bodies, metrics, and outcome counts remain frozen.

`backend/test/invite-delivery.test.ts` may change only to construct the real
adapter and pass it to `InvitationDeliveryService`. The current global-fetch
fixtures and all assertions remain intact, so the test continues proving the
real hardened endpoint, body, acknowledgement, and status mapping through the
new port.

New tests must prove:

- exact TypeChecker identity for token, interface, consumer class, parameter,
  and implementation;
- one concrete adapter registration and one public binding globally;
- `token === implementation alias === concrete adapter instance`;
- wrong-owner module, `useClass`, duplicate registration, local same-name
  Symbol, fake interface, same-file decoy, and wrong constructor parameter fail;
- Collaboration cannot import Identity internal or platform concrete transport;
- the adapter cannot import Prisma, start a transaction, retry, log, mutate the
  input, or call the sender more than once;
- platform errors map exactly and unexpected error identity is preserved;
- the current disabled/null-phone error precedence remains unchanged.

No existing assertion may be deleted, skipped, loosened, or replaced with a
regex-only identity check.

## Fixed-Base Evidence

R6 introduces a manifest and gate tied to the immutable R6 base. The manifest
records:

- exact base revision;
- the one retired concrete transport debt;
- exact public token, interface, implementation, consumer class, constructor
  parameter, and method names;
- the expected dependency count of 31;
- ownership 385 records / 781 occurrences;
- the exact allowed changed-path fence;
- frozen hashes for platform transport, invitation behavior contracts, Prisma
  schema/migrations/seed, package/lock security state, Mobile, Admin,
  workflows, Compose, and deployment.

The gate must use Git diff with rename detection disabled, validate plain data
recursively, reject missing/extra/reordered/substituted paths, and fail closed
on stale debt, local-token aliases, decoy injections, duplicate providers, or
baseline drift.

R3 remains the canonical provider/source-law scanner. R6 extends its validated
provider contract and exact constructor inventory; it does not weaken the R3
receipt or silently regenerate its manifest.

## Verification Contract

### Focused

- R6 manifest/scope/source-law tests;
- R3 provider and module laws;
- invitation delivery behavior;
- OpenWA transient sender, OTP channel, and credential rotation;
- Sharing create/reissue status persistence;
- Identity public module and DI compilation.

### Full local

- `npm run architecture:r6`;
- full `npm run architecture`;
- `npm run check`;
- `npm run build`;
- full Backend tests with artifact guard;
- Prisma validate/generate and frozen 14/52/41/76 evidence;
- both npm audits with zero findings;
- managed auth, auth-verification, OTP profile, sharing, invitation/security,
  health, and aggregate `smoke:all`;
- docs sync/verify/diff;
- exact protected-surface and residue audits.

The external `smoke:openwa-otp` command is not automatic R6 evidence. It sends
a real WhatsApp message and requires the existing explicit confirmation plus a
dedicated test recipient. It may run only after separate owner authorization.

### Runtime and phone

Build one immutable R6 image labeled with the exact application-candidate SHA.
Probe it on a unique loopback port, verify migration discovery and safe logs,
then cut over locally with the R5 image/container preserved for rollback.

The owner phone checkpoint must use an authenticated account and exercise:

- login/session restoration;
- plan sharing or members;
- create or reissue one safe invitation;
- verify the returned/persisted delivery state;
- one related read after the write;
- complete force-close and reopen.

If the local runtime has OpenWA disabled, the phone gate proves the preserved
unavailable path and application continuity. It does not claim a real WhatsApp
delivery. A real-message claim requires the separately authorized external
smoke.

## Non-Goals

R6 does not:

- move all `sharing/` or `contribution-history/` source into
  `modules/collaboration`;
- change invite routes, DTOs, response payloads, database writes, permissions,
  transactions, Arabic copy, timeout, retry, metrics, or provider semantics;
- change AuthService OTP generation/channel selection;
- modify OpenWA/WhatsApp transport source, credentials, deployment, or network
  topology;
- add email, SMS, push, fallback, retry queue, or another messaging provider;
- remove either approved global; that remains R8;
- change schema, migrations, seed, model ownership, Mobile, Admin, package
  versions, workflows, Compose, or deployment;
- create compatibility facades, duplicate implementations, default constructor
  fallbacks, fake tokens, or permanent baseline exceptions;
- begin R7, R8, R9, or R10;
- push, merge, mutate PR #76, deploy, or claim remote CI.

## Rejected Alternatives

- **Keep the direct import:** rejected because it leaves the explicit R1/R3
  migration debt unresolved.
- **Move message construction into Identity:** rejected because Collaboration
  owns invitation content and privacy semantics.
- **Expose the OpenWA sender from Platform as a public business API:** rejected
  because it preserves provider-specific coupling and ignores the deferred
  Identity seam.
- **Add a default adapter inside the service constructor:** rejected because it
  hides DI errors and permits a second implementation path.
- **Return provider status codes/message IDs through the port:** rejected
  because callers do not need them and they would expand the contract.
- **Use `useClass` in the public module:** rejected because it creates a second
  instance and breaks singleton identity.
- **Run the real OpenWA smoke automatically:** rejected because it is an
  external message mutation requiring explicit confirmation.
- **Combine the change with Collaboration relocation or R8 globals:** rejected
  because it broadens the risk and phase surface.

## Acceptance Summary

R6 is accepted locally only when the direct Collaboration-to-concrete-OpenWA
dependency is gone, the exact Identity public port resolves to one internal
adapter instance, all observable invitation behavior remains identical, every
focused/full/smoke/runtime/phone gate passes, the independent review has no
unresolved finding, truthful receipts are committed locally, and the worktree
is clean.

No push, merge, PR mutation, deployment, remote CI, real WhatsApp-send claim,
or R7 start is implied by local R6 completion.
