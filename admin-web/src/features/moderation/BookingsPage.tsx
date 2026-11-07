// a12 «الحجوزات», read only (B-40). The drawn «الخلافات» card and its
// actions are the «ما صار» reports of B-22, which are not built, so the page
// lists the bookings with their filters and opens one: the day, the two
// sides, who ended it and why. No amount, offer or payment is shown: اعّرست
// keeps no money, and the customer's money is his.
import { useCallback, useEffect, useState } from 'react';
import { getBooking, getBookings, type AdminBooking } from './api';
import { getProviders, type ProviderApplication } from '../providers/api';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  Tag,
  TwoLine,
} from '../../design_system/Desk';
import { dayMonth } from '../../platform/i18n/deskTime';

type Page = {
  items: AdminBooking[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

type Filters = { providerId: string; status: string; from: string; to: string };

const NO_FILTERS: Filters = { providerId: '', status: '', from: '', to: '' };

/** The booking's state as the desk says it. */
export function bookingStateLabel(booking: AdminBooking): {
  label: string;
  tone: 'green' | 'saffron' | 'coral' | 'muted' | 'teal';
} {
  switch (booking.lifecycleStatus) {
    case 'REQUESTED':
      return { label: 'ينتظر المزود', tone: 'saffron' };
    case 'CONFIRMED':
      return { label: 'مؤكد', tone: 'green' };
    case 'COMPLETED':
      return { label: 'تم', tone: 'teal' };
    case 'DECLINED':
      return { label: 'اعتذر المزود', tone: 'muted' };
    case 'CANCELLED':
      return {
        label: booking.cancelledBy === 'PROVIDER' ? 'ألغاه المزود' : 'ألغاه العميل',
        tone: 'coral',
      };
    case 'EXPIRED':
      return { label: 'انتهى مع إيقاف المزود', tone: 'muted' };
  }
}

function endedLine(booking: AdminBooking): string | null {
  const at = booking.cancelledAt ?? booking.declinedAt ?? booking.expiredAt;
  if (!at) return null;
  const who =
    booking.status === 'DECLINED'
      ? 'اعتذر المزود'
      : booking.status === 'EXPIRED'
        ? 'انتهى لما انوقف المزود'
        : booking.cancelledBy === 'PROVIDER'
          ? 'ألغاه المزود'
          : 'ألغاه العميل';
  return `${who} ${dayMonth(at)}`;
}

export function BookingsPage() {
  const [filters, setFilters] = useState<Filters>(NO_FILTERS);
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [providers, setProviders] = useState<ProviderApplication[]>([]);
  const [open, setOpen] = useState<AdminBooking | null>(null);
  const [openError, setOpenError] = useState<string | null>(null);

  // RA-AD-16: the server refuses «من يوم» after «إلى يوم»; the desk says so
  // itself rather than asking. ISO days compare as text.
  const backwards = filters.from !== '' && filters.to !== '' && filters.from > filters.to;

  const load = useCallback(async () => {
    setError(null);
    if (filters.from !== '' && filters.to !== '' && filters.from > filters.to) return;
    try {
      setResult(
        await getBookings({
          providerId: filters.providerId || undefined,
          status: filters.status || undefined,
          from: filters.from || undefined,
          to: filters.to || undefined,
          page,
          limit: 20,
        }),
      );
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الحجوزات.');
    }
  }, [filters, page]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    getProviders({ status: 'ACTIVE', limit: 100 })
      .then((list) => setProviders(list.items))
      .catch(() => setProviders([]));
  }, []);

  function filter(next: Partial<Filters>) {
    setFilters((current) => ({ ...current, ...next }));
    setPage(1);
    setResult(null);
  }

  async function show(booking: AdminBooking) {
    setOpen(booking);
    setOpenError(null);
    try {
      setOpen(await getBooking(booking.id));
    } catch (value) {
      setOpenError(value instanceof Error ? value.message : 'ما قدرنا نقرأ الحجز.');
    }
  }

  return (
    <section>
      <DeskHeader
        title="الحجوزات"
        sub="اعّرست ما يمسك فلوس: نشوف الحجز ومين أنهاه وليش، بدون مبالغ"
        actions={
          filters === NO_FILTERS ? null : (
            <DeskButton tone="soft" onClick={() => filter(NO_FILTERS)}>
              كل الحجوزات
            </DeskButton>
          )
        }
      />
      <div className="desk-row" role="search" style={{ alignItems: 'flex-end' }}>
        <label className="desk-field">
          المزود
          <select
            aria-label="المزود"
            value={filters.providerId}
            onChange={(event) => filter({ providerId: event.target.value })}
          >
            <option value="">كل المزودين</option>
            {providers.map((provider) => (
              <option key={provider.id} value={provider.id}>
                {provider.businessName}
              </option>
            ))}
          </select>
        </label>
        <label className="desk-field">
          الحالة
          <select
            aria-label="الحالة"
            value={filters.status}
            onChange={(event) => filter({ status: event.target.value })}
          >
            <option value="">الكل</option>
            <option value="REQUESTED">ينتظر المزود</option>
            <option value="CONFIRMED">مؤكد</option>
            <option value="DECLINED">اعتذر المزود</option>
            <option value="CANCELLED">ملغي</option>
            <option value="EXPIRED">انتهى مع إيقاف المزود</option>
          </select>
        </label>
        <label className="desk-field">
          من يوم
          <input
            type="date"
            aria-label="من يوم"
            value={filters.from}
            onChange={(event) => filter({ from: event.target.value })}
          />
        </label>
        <label className="desk-field">
          إلى يوم
          <input
            type="date"
            aria-label="إلى يوم"
            value={filters.to}
            min={filters.from || undefined}
            onChange={(event) => filter({ to: event.target.value })}
          />
        </label>
      </div>
      {open ? (
        <Panel border="teal">
          <TwoLine
            main={`${open.provider.businessName} مع ${open.customer.name ?? 'العميل'}`}
            sub={[
              dayMonth(`${open.eventDate}T12:00:00Z`),
              ...(open.guestCount ? [`${open.guestCount} ضيف تقريبًا`] : []),
              `طلبه ${dayMonth(open.requestedAt)}`,
              ...(open.confirmedAt ? [`أكّده المزود ${dayMonth(open.confirmedAt)}`] : []),
            ].join(' · ')}
          />
          <p>
            <Tag tone={bookingStateLabel(open).tone}>{bookingStateLabel(open).label}</Tag>{' '}
            {endedLine(open) ?? ''}
          </p>
          {open.note ? <p>السبب: «{open.note}»</p> : null}
          {openError ? <DeskNote tone="coral">{openError}</DeskNote> : null}
          <DeskButton tone="soft" onClick={() => setOpen(null)}>
            سكّر
          </DeskButton>
        </Panel>
      ) : null}
      {backwards ? <DeskNote tone="coral">«من يوم» بعد «إلى يوم»: بدّل واحد منهم.</DeskNote> : null}
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {result === null && !error && !backwards ? <DeskNote>لحظة، نحمّل الحجوزات…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه حجز بهذي الفلاتر.</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <DeskTable
            caption="الحجوزات"
            columns={[
              { label: 'الحجز', flex: 4 },
              { label: 'المزود', flex: 3 },
              { label: 'اليوم', flex: 2 },
              { label: 'الحالة', flex: 2 },
            ]}
            rows={result.items}
            rowKey={(booking) => booking.id}
            onRowClick={(booking) => void show(booking)}
            rowLabel={(booking) =>
              `حجز ${booking.customer.name ?? 'العميل'} مع ${booking.provider.businessName}`
            }
            renderRow={(booking) => {
              const state = bookingStateLabel(booking);
              return [
                <TwoLine
                  key="b"
                  main={booking.customer.name ?? 'العميل'}
                  sub={endedLine(booking) ?? undefined}
                />,
                booking.provider.businessName,
                dayMonth(`${booking.eventDate}T12:00:00Z`),
                <Tag key="s" tone={state.tone}>
                  {state.label}
                </Tag>,
              ];
            }}
          />
          <DeskPager
            page={result.page}
            limit={result.limit}
            total={result.total}
            totalPages={result.totalPages}
            onPageChange={setPage}
          />
        </>
      ) : null}
    </section>
  );
}
