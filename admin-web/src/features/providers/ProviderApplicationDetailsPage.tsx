// a04 «مراجعة طلب» (mobile/test/prototype/admin/admin_screens.dart
// `a04Review`): the application field by field and its review line. The note
// per field and «قبل التعديل» wait for B-01 (one note goes with «اطلب
// تعديل»), «يخدم» has no field, the teams left with D41, and the quick
// checks need B-16, B-07 and A-07, so that panel is not drawn.
import { type ReactNode, useCallback, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import {
  getProviderApplication,
  type ProviderApplication,
  type ProviderPackageProjection,
  type ProviderServiceProjection,
} from './api';
import { ProviderDecisions, providerStatusWord } from './providerHelpers';
import {
  DeskHeader,
  DeskNote,
  DeskRetry,
  Panel,
  TwoLine,
  grouped,
} from '../../design_system/Desk';
import { whenShort } from '../../platform/i18n/deskTime';

function money(amount: string | null, currency: string): string | null {
  if (amount === null || amount === '') return null;
  return `${grouped(amount)} ${currency === 'YER' ? 'ر.ي' : currency}`;
}

function photoCount(count: number): string {
  if (count === 0) return 'ما فيه صور';
  if (count === 1) return 'صورة وحدة';
  if (count === 2) return 'صورتين';
  if (count <= 10) return `${count} صور`;
  return `${count} صورة`;
}

function serviceLine(service: ProviderServiceProjection): string {
  return [money(service.basePrice, service.currency), service.description]
    .filter(Boolean)
    .join(' · ') || 'بدون سعر';
}

function packageLine(item: ProviderPackageProjection): string {
  const included = Array.isArray(item.items)
    ? item.items.filter((entry): entry is string => typeof entry === 'string').join('، ')
    : '';
  return [money(item.price, item.currency), included || item.description]
    .filter(Boolean)
    .join(' · ') || 'بدون سعر';
}

function decisionLine(provider: ProviderApplication): string | null {
  if (!provider.reviewedAt) return null;
  const who = provider.reviewedBy?.name ?? 'الإدارة';
  switch (provider.status) {
    case 'NEEDS_CHANGES':
      return `${who} طلب تعديل`;
    case 'REJECTED':
      return `${who} رفض الطلب`;
    case 'ACTIVE':
      return `${who} اعتمد الطلب`;
    case 'SUSPENDED':
      return `${who} أوقف الملف`;
    default:
      return null;
  }
}

function Field({ label, value, children }: { label: string; value: string; children?: ReactNode }) {
  return (
    <div className="desk-field-card">
      <TwoLine main={label} sub={value} />
      {children}
    </div>
  );
}

export function ProviderApplicationDetailsPage() {
  const { id = '' } = useParams();
  const [provider, setProvider] = useState<ProviderApplication | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setProvider(await getProviderApplication(id));
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الطلب.');
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!provider) {
    return error ? <DeskRetry message={error} onRetry={() => void load()} /> : <DeskNote>لحظة، نحمّل الطلب…</DeskNote>;
  }

  const services = provider.services ?? [];
  const packages = provider.packages ?? [];
  const photos = services.reduce((sum, service) => sum + (service.images?.length ?? 0), 0);
  const where = [provider.primaryCategory?.nameAr, provider.city?.nameAr].filter(Boolean);
  const state = provider.status === 'PENDING'
    ? `قدّم ${whenShort(provider.createdAt)}`
    : providerStatusWord(provider.status);
  const decision = decisionLine(provider);

  return (
    <section className="desk-fill-page">
      <DeskHeader
        title={provider.businessName}
        sub={[...where, state].join(' · ')}
        actions={<ProviderDecisions provider={provider} onChanged={load} />}
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      <div className="desk-split">
        <div className="desk-split__main desk-field-stack" style={{ flex: 3 }}>
          <Field label="النشاط" value={provider.businessName}>
            {provider.description ? <p className="desk-field-card__more">{provider.description}</p> : null}
          </Field>
          <Field label="صور الشغل" value={photoCount(photos)} />
          {services.map((service) => (
            <Field key={service.id} label={service.title} value={serviceLine(service)} />
          ))}
          {packages.map((item) => (
            <Field key={item.id} label={item.title} value={packageLine(item)} />
          ))}
          <Field
            label="المناطق"
            value={[provider.city?.nameAr, provider.address].filter(Boolean).join(' · ') || '—'}
          />
        </div>
        <div className="desk-split__side desk-split__side--fill" style={{ flex: 2 }}>
          <Panel>
            <h2 className="desk-panel__title">خط المراجعة</h2>
            <ol className="desk-timeline">
              <li>
                <span>{whenShort(provider.createdAt)}</span>
                <span>قدّم الطلب</span>
              </li>
              {decision && provider.reviewedAt ? (
                <li>
                  <span>{whenShort(provider.reviewedAt)}</span>
                  <span>
                    {decision}
                    {provider.reviewNote ? (
                      <strong className="desk-timeline__note">للمزود: {provider.reviewNote}</strong>
                    ) : null}
                  </span>
                </li>
              ) : null}
            </ol>
          </Panel>
        </div>
      </div>
    </section>
  );
}
