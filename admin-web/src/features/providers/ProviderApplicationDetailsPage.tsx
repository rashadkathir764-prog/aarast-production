// a04 «مراجعة طلب»: the application field by field, a «ملاحظة» on each field the
// provider can fix (B-01), and the review line from the history (B-01,
// B-02). «قبل التعديل» needs the earlier values, which are not kept; «يخدم»
// has no field; the teams left with D41; the quick checks need B-16, B-07
// and A-07, so that panel is not drawn.
import { type ReactNode, useCallback, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import {
  getProviderApplication,
  getProviderReviewHistory,
  type ProviderApplication,
  type ProviderFieldNote,
  type ProviderPackageProjection,
  type ProviderReviewEvent,
  type ProviderReviewField,
  type ProviderServiceProjection,
} from './api';
import { ProviderDecisions, providerActionVisibility, providerStatusWord } from './providerHelpers';
import {
  DeskHeader,
  DeskNote,
  DeskRetry,
  Panel,
  SoftAction,
  TwoLine,
  grouped,
} from '../../design_system/Desk';
import { AdminPermission, hasAdminPermission, useAuth } from '../auth/api';
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

function fieldCount(count: number): string {
  if (count === 1) return 'في حقل';
  if (count === 2) return 'في حقلين';
  return `في ${count} حقول`;
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

/** One step of the review line, in the design's words (a04 «خط المراجعة»). */
export function reviewStepLine(event: ProviderReviewEvent): string {
  const who = event.actor?.name ?? 'الإدارة';
  switch (event.kind) {
    case 'CHANGES_REQUESTED': {
      const fields = event.notes.filter((note) => note.field !== 'GENERAL').length;
      return fields > 0 ? `${who} طلب تعديل ${fieldCount(fields)}` : `${who} طلب تعديل`;
    }
    case 'REJECTED':
      return `${who} رفض الطلب`;
    case 'APPROVED':
      return `${who} اعتمد الطلب`;
    case 'SUSPENDED':
      return `${who} أوقف الملف`;
    case 'ACTIVATED':
      return `${who} رجّع الملف`;
    case 'RESUBMITTED':
      return 'المزود أرسل التعديل';
    case 'REOPENED':
      return 'المزود قدّم من جديد بعد الرفض';
  }
}

/** The step's note about the whole profile (the refusal's reason, the general note). */
function generalNote(event: ProviderReviewEvent): string | null {
  return event.notes.find((note) => note.field === 'GENERAL')?.note ?? null;
}

/** Each field a note can point at, named as its card names it. */
const FIELD_LABELS: Record<ProviderReviewField, string> = {
  BUSINESS_NAME: 'النشاط',
  CATEGORY: 'القسم',
  DESCRIPTION: 'النبذة',
  SERVICE: 'الخدمة وسعرها',
  CITY: 'المناطق',
};

/** The fields in the order the page shows them. */
const FIELD_ORDER: ProviderReviewField[] = [
  'BUSINESS_NAME',
  'CATEGORY',
  'DESCRIPTION',
  'SERVICE',
  'CITY',
];

/** The step's note on each field, under the field's name. */
function fieldNotesOf(event: ProviderReviewEvent): ProviderFieldNote[] {
  return event.notes.filter(
    (note): note is ProviderFieldNote => note.field !== 'GENERAL',
  );
}

/**
 * What «اطلب تعديل» sends: the notes he reads now on every field, each one
 * replaced by what the reviewer wrote in its open box (an emptied box drops
 * it). A rewrite while he fixes (B-01) replaces every note, so a note the
 * reviewer did not open is sent again rather than lost.
 */
export function outgoingFieldNotes(
  current: readonly ProviderFieldNote[],
  drafts: Partial<Record<ProviderReviewField, string>>,
): ProviderFieldNote[] {
  const now = new Map(current.map((note) => [note.field, note.note]));
  return FIELD_ORDER.flatMap((field) => {
    const draft = drafts[field];
    const note = (draft !== undefined ? draft : now.get(field))?.trim();
    return note ? [{ field, note }] : [];
  });
}

type FieldProps = {
  label: string;
  value: string;
  field?: ProviderReviewField;
  /** The note the provider reads now on this field. */
  current?: string;
  /** The note being written for the next «اطلب تعديل»; undefined while closed. */
  draft?: string;
  canNote: boolean;
  onDraft: (field: ProviderReviewField, note: string | undefined) => void;
  children?: ReactNode;
};

function Field({ label, value, field, current, draft, canNote, onDraft, children }: FieldProps) {
  const open = draft !== undefined;
  return (
    <div className={`desk-field-card${open ? ' desk-field-card--noting' : ''}`}>
      <div className="desk-field-card__row">
        <TwoLine main={label} sub={value} />
        {field && canNote ? (
          <SoftAction
            aria-expanded={open}
            aria-label={`ملاحظة على ${label}`}
            onClick={() => onDraft(field, open ? undefined : current ?? '')}
          >
            ملاحظة
          </SoftAction>
        ) : null}
      </div>
      {children}
      {current && !open ? <p className="desk-field-card__note">للمزود: {current}</p> : null}
      {field && open ? (
        <label className="desk-field-card__editor">
          <span>ملاحظتك على {label}</span>
          <textarea
            value={draft}
            rows={2}
            onChange={(event) => onDraft(field, event.target.value)}
          />
        </label>
      ) : null}
    </div>
  );
}

export function ProviderApplicationDetailsPage() {
  const { id = '' } = useParams();
  const { user } = useAuth();
  const [provider, setProvider] = useState<ProviderApplication | null>(null);
  const [history, setHistory] = useState<ProviderReviewEvent[] | null>(null);
  const [drafts, setDrafts] = useState<Partial<Record<ProviderReviewField, string>>>({});
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [next, steps] = await Promise.all([
        getProviderApplication(id),
        getProviderReviewHistory(id),
      ]);
      setProvider(next);
      setHistory(steps.events);
      setDrafts({});
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
    ? provider.resubmittedAt
      ? `أُعيد إرساله ${whenShort(provider.resubmittedAt)}`
      : `قدّم ${whenShort(provider.createdAt)}`
    : providerStatusWord(provider.status);
  const canNote =
    providerActionVisibility(provider.status).requestChanges &&
    hasAdminPermission(user, AdminPermission.PROVIDERS_WRITE);
  const current = new Map(provider.fieldNotes.map((note) => [note.field, note.note]));
  const draftNotes = outgoingFieldNotes(provider.fieldNotes, drafts);
  const onDraft = (field: ProviderReviewField, note: string | undefined) =>
    setDrafts((previous) => ({ ...previous, [field]: note }));
  const fieldProps = (field: ProviderReviewField) => ({
    field,
    current: current.get(field),
    draft: drafts[field],
    canNote,
    onDraft,
  });

  return (
    <section className="desk-fill-page">
      <DeskHeader
        title={provider.businessName}
        sub={[...where, state].join(' · ')}
        actions={<ProviderDecisions provider={provider} fieldNotes={draftNotes} onChanged={load} />}
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      <div className="desk-split">
        <div className="desk-split__main desk-field-stack" style={{ flex: 3 }}>
          <Field
            label={FIELD_LABELS.BUSINESS_NAME}
            value={provider.businessName}
            {...fieldProps('BUSINESS_NAME')}
          />
          <Field
            label={FIELD_LABELS.CATEGORY}
            value={provider.primaryCategory?.nameAr ?? '—'}
            {...fieldProps('CATEGORY')}
          />
          <Field
            label={FIELD_LABELS.DESCRIPTION}
            value={provider.description ?? 'ما كتب نبذة'}
            {...fieldProps('DESCRIPTION')}
          />
          {services.length === 0 ? (
            <Field label={FIELD_LABELS.SERVICE} value="ما أضاف خدمة" {...fieldProps('SERVICE')} />
          ) : null}
          {services.map((service, index) => (
            <Field
              key={service.id}
              label={service.title}
              value={serviceLine(service)}
              {...(index === 0 ? fieldProps('SERVICE') : { canNote: false, onDraft })}
            />
          ))}
          <Field label="صور الشغل" value={photoCount(photos)} canNote={false} onDraft={onDraft} />
          {packages.map((item) => (
            <Field
              key={item.id}
              label={item.title}
              value={packageLine(item)}
              canNote={false}
              onDraft={onDraft}
            />
          ))}
          <Field
            label={FIELD_LABELS.CITY}
            value={[provider.city?.nameAr, provider.address].filter(Boolean).join(' · ') || '—'}
            {...fieldProps('CITY')}
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
              {(history ?? []).map((event) => {
                const note = generalNote(event);
                return (
                  <li key={event.id}>
                    <span>{whenShort(event.at)}</span>
                    <span>
                      {reviewStepLine(event)}
                      {note ? <strong className="desk-timeline__note">للمزود: {note}</strong> : null}
                      {fieldNotesOf(event).map((fieldNote) => (
                        <strong key={fieldNote.field} className="desk-timeline__note">
                          {FIELD_LABELS[fieldNote.field]}: {fieldNote.note}
                        </strong>
                      ))}
                    </span>
                  </li>
                );
              })}
            </ol>
            {canNote ? (
              <p className="desk-field-card__more">ملاحظتك تظهر للمزود جنب الحقل نفسه.</p>
            ) : null}
          </Panel>
        </div>
      </div>
    </section>
  );
}
