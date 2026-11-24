// RA-BE-152 (Q-39 (أ), D124) «تعديلات الملفات». Once a provider is approved,
// his new name, logo, cover, city or category waits here, the oldest first;
// customers keep seeing the old until the team approves («وافق»). A refusal
// («ارفض») keeps the listing as it is, deletes the images he sent and tells
// him why. Every decision is in the audit log with its reason.
import { useCallback, useEffect, useState } from 'react';
import { decideProfileChange, getProfileChanges, type ProfileChange } from './api';
import { AdminPermission, Can } from '../auth/api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { DeskHeader, DeskNote, DeskPager, DeskRetry, Panel, SoftAction } from '../../design_system/Desk';
import { pageToShow } from '../../platform/api/query';

type Page = {
  items: ProfileChange[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

const named = (value: { nameAr: string | null } | null) => value?.nameAr ?? '—';

/** «الاسم: القديم ← الجديد» for each field he asked to change. */
function changedLines(change: ProfileChange): string[] {
  const { asked, provider } = change;
  return [
    asked.businessName !== null ? `الاسم: ${provider.businessName} ← ${asked.businessName}` : null,
    asked.city !== null ? `المدينة: ${named(provider.city)} ← ${named(asked.city)}` : null,
    asked.primaryCategory !== null
      ? `الفئة: ${named(provider.primaryCategory)} ← ${named(asked.primaryCategory)}`
      : null,
  ].filter((line): line is string => line !== null);
}

function Images({ change, image }: { change: ProfileChange; image: 'logo' | 'cover' }) {
  const word = image === 'logo' ? 'الشعار' : 'الغلاف';
  const next = image === 'logo' ? change.asked.logoUrl : change.asked.coverUrl;
  const now = image === 'logo' ? change.provider.logoUrl : change.provider.coverUrl;
  if (!next) return null;
  const name = change.provider.businessName;
  return (
    <>
      <img className="desk-photo__image" src={next} alt={`${word} الجديد لـ ${name}`} loading="lazy" />
      <small>
        {now ? (
          <>
            {`${word} الحالي: `}
            <img src={now} alt={`${word} الحالي لـ ${name}`} width={32} height={32} loading="lazy" />
          </>
        ) : (
          `ما عنده ${word} الحين`
        )}
      </small>
    </>
  );
}

export function ProfileChangesPage() {
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const next = await getProfileChanges({ status: 'PENDING', page, limit: 24 });
      // RA-AD-12: past the last page after its last request was decided.
      const shown = pageToShow(page, next.totalPages);
      if (shown !== page) {
        setPage(shown);
        return;
      }
      setResult(next);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل التعديلات.');
    }
  }, [page]);

  useEffect(() => {
    void load();
  }, [load]);

  async function approve(change: ProfileChange) {
    setBusyId(change.id);
    setActionError(null);
    try {
      await decideProfileChange(change.id, { decision: 'APPROVE' });
      await load();
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا نوافق على التعديل.');
    } finally {
      setBusyId(null);
    }
  }

  async function refuse(change: ProfileChange, reason: string) {
    setActionError(null);
    await decideProfileChange(change.id, { decision: 'REJECT', reason });
    await load();
  }

  return (
    <section>
      <DeskHeader title="تعديلات الملفات" sub="اسم أو شعار أو غلاف أو مدينة أو فئة غيّرها مزود معتمد · الأقدم أول" />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {actionError ? (
        // RA-AD-18: trying again starts clean.
        <DeskRetry
          message={actionError}
          onRetry={() => {
            setActionError(null);
            void load();
          }}
        />
      ) : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل التعديلات…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه تعديلات تنتظر المراجعة.</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <ul className="desk-photos" aria-label="تعديلات الملفات">
            {result.items.map((change) => (
              <li key={change.id} className="desk-photo">
                <Images change={change} image="logo" />
                <Images change={change} image="cover" />
                <strong>{change.provider.businessName}</strong>
                {changedLines(change).map((line) => (
                  <small key={line}>{line}</small>
                ))}
                <Can permission={AdminPermission.PROVIDERS_WRITE}>
                  <span className="desk-actions">
                    <ConfirmDialog
                      title={`ارفض تعديل ${change.provider.businessName}`}
                      effects={[
                        'ملفه يبقى مثل ما هو عند العرسان.',
                        'الصور اللي رفعها للتعديل تنحذف من التخزين.',
                        'المزود يوصله إن التعديل ما نزل والسبب اللي تكتبه.',
                      ]}
                      needsNote
                      noteMaxLength={400} // AdminProfileChangeDecisionDto.reason
                      noteLabel="ليش ما نزل؟ (يقرأه المزود)"
                      confirmLabel="ارفض"
                      confirmTone="coral"
                      trigger={<SoftAction tone="coral">ارفض</SoftAction>}
                      onConfirm={(reason) => refuse(change, reason)}
                    />
                    <SoftAction
                      tone="green"
                      disabled={busyId === change.id}
                      onClick={() => void approve(change)}
                    >
                      وافق
                    </SoftAction>
                  </span>
                </Can>
              </li>
            ))}
          </ul>
          <DeskPager
            page={result.page}
            limit={result.limit}
            total={result.total}
            totalPages={result.totalPages}
            onPageChange={setPage}
          />
        </>
      ) : null}
      <DeskNote>العرسان يشوفون الملف القديم لين توافق. والمزود يوصله القرار.</DeskNote>
    </section>
  );
}
