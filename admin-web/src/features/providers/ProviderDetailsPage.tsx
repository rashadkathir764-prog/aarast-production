// a06 «تفاصيل مزود» and its suspension (mobile/test/prototype/admin/
// admin_screens.dart `a06ProviderSuspend`). «حجوزات جاية» waits for B-40 and
// «بلاغات» for A-21; the server counts every quote request, so the card says
// «طلبات العروض». The suspension window keeps only what the server does
// today: the two lines about bookings and open requests wait for B-42.
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { getProvider, type ProviderApplication } from './api';
import { ProviderDecisions, providerStatusWord } from './providerHelpers';
import {
  DeskHeader,
  DeskNote,
  DeskRetry,
  Stat,
  StatRow,
  grouped,
} from '../../design_system/Desk';
import { monthName } from '../../platform/i18n/deskTime';

export function ProviderDetailsPage() {
  const { id = '' } = useParams();
  const [provider, setProvider] = useState<ProviderApplication | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setProvider(await getProvider(id));
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل المزود.');
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!provider) {
    return error ? <DeskRetry message={error} onRetry={() => void load()} /> : <DeskNote>لحظة، نحمّل المزود…</DeskNote>;
  }

  const since = provider.reviewedAt ?? provider.createdAt;
  const sub = [
    provider.primaryCategory?.nameAr,
    provider.city?.nameAr,
    `${providerStatusWord(provider.status)} من ${monthName(since)}`,
  ]
    .filter(Boolean)
    .join(' · ');

  return (
    <section>
      <DeskHeader
        title={provider.businessName}
        sub={sub}
        actions={<ProviderDecisions provider={provider} onChanged={load} />}
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      <StatRow>
        <Stat value={grouped(provider.quoteRequestsCount)} label="طلبات العروض" />
        <Stat
          value={provider.ratingCount ? Number(provider.ratingAverage).toFixed(1) : '—'}
          label="التقييم"
          sub={provider.ratingCount ? `${provider.ratingCount} تقييم` : undefined}
        />
      </StatRow>
    </section>
  );
}
