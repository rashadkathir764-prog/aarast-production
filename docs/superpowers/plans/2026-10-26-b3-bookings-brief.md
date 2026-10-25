# B3 brief: bookings and capacity (2026-10-26)

**For:** the agent that builds slice B3.
**Sources:** a read-only research pass over HEAD `4b0e5521`, plus the lead's decisions below. Spec items B-20, B-18, B-42 and B-33 are in `2026-10-25-provider-backend-changes.md`.

## Lead decisions (record as one D-row when B3 lands)
1. **Capacity (B-20).**
   - Add `Provider.dailyBookingCapacity`: default 1, range 1–20, editable from the provider profile.
   - Only CONFIRMED bookings take a seat. A REQUESTED booking does not hold one.
   - The check is `confirmed count >= capacity`, which returns `409 BOOKING_DAY_FULL`. It runs at request time and again at confirm.
   - Drop the partial unique index `Booking_provider_confirmed_date_key`. The provider row lock is then the only guard, so a concurrency test is required.
   - Lowering the capacity below the bookings that already exist keeps those bookings and refuses new confirms.
2. **One definition of «محجوز».** A plan's service is booked when it has a CONFIRMED booking, or when its cost is recorded with an outside party.
   - Compute this in one backend function.
   - The home tile and the providers board both read that function. Today the home counts accepted-offer links instead (`provider-read.service.ts:82-90`).
   - An accepted offer with no booking is the state «اخترت X · اطلب الحجز». It never counts as booked.
3. **Agreed / paid / remaining for the provider (B-18).**
   - Widen the public finance port: `totalAmount`, `paidAmount`, `status`, `currency`, `lastPaidAt`.
   - Add `money` to the provider's bookings and requests.
   - Add `GET /api/v1/provider/me/ledger?month=` for p47.
   - The provider sees only the three totals.
   - **Start this part only after the B5 review fixes are committed**, because they also change the finance port.
4. **Suspension (B-42).**
   - It means admin suspend, as the plan says. V1 has no provider-side pause switch, because none is drawn.
   - On suspend: the provider's REQUESTED bookings expire, and those grooms are notified.
   - Confirmed bookings stay, and their grooms are told «موقوف مؤقتًا، حجزك المؤكد باقي».
   - `blocked-dates` needs an approved account.
5. **Deleting an account that has bookings (B-33).**
   - `DELETE /users/me` returns `409 PROVIDER_HAS_UPCOMING_BOOKINGS {count, bookingIds}` when the user owns a provider with CONFIRMED bookings from today on. The check runs before any destructive step.
   - Grooms with open requests are told «المزود أغلق حسابه» before those requests are purged.
   - The grace-period delete (A-15, n06) is not part of B3.
6. **Admin bookings a12 (B-40).** A read-only list with filters (provider, status, from, to) and a detail view. The «ما صار» reports (B-22) are not part of B3.
7. **Demo data.**
   - `hospitalityBride` in `backend/prisma/demo-seed/market-data.ts` gets `booking: { date: WEDDING_DAY, status: CONFIRMED }`.
   - One provider gets capacity 2, with two confirmed bookings on one day, so the demo exercises capacity.

## Code today (from the research)
**Bookings**
- The model is at `marketplace.prisma:339-360`. `quoteRequestId` is unique.
- The one-per-day rule is a raw partial index in `migrations/20261015120000_add_bookings_and_provider_calendar/migration.sql:66-72`.
- The service is `backend/src/marketplace/bookings.service.ts`:
  - `requestBooking` is at :96-155.
  - `decideAsProvider` is at :247-290.
  - `blockDate` is at :302-320.
  - `assertDayAvailable` is at :430-441. It relies on `hasConfirmedBookingOn`, a boolean, in `marketplace-booking.repository.ts:49-64`.

**Home count**
- `dashboard.service.ts:226,394,445-446` uses `countActivePlanProviderLinks`.
- The board's count is in `mobile/lib/features/marketplace/models/provider_board.dart:189-211`.
- These also read the home count:
  - `dashboard-summary.presenter.ts:55,210`
  - `dashboard.contracts.ts:55-60`
  - `dashboard_summary.dart:166-168`

**Deletion**
- The erasure saga is in `users.service.ts:~330-520`. Provider deletion cascades to bookings.
- `WeddingCost.providerId` and `quoteOfferId` are SetNull (`finance.prisma:99-100`).

**Admin suspend** is `admin.service.ts:523`.

**Screens**
- Provider: p21 p22 p25 p28 p29 p40 p47 p12.
- Groom: f01 f05 f06 f07 and c07.
- Admin: a12.
