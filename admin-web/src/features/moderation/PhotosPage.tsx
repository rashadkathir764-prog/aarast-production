// n07 «صور تحتاج مراجعة» (D62). Every new portfolio photo waits here, the oldest first; the
// moderation team approves it («سليمة») or refuses it with its reason
// («شِل»), and the provider is told either way. A women's-album photo is
// approved only after the reviewer confirms it shows no faces. Not built
// (recorded): the drawn automatic face hints («آلي: وجه واضح») and the
// brides' reports («بلاغ من عروسة»), which have no source; the drawn
// two-hour promise; the search box.
import { useCallback, useEffect, useState } from 'react';
import { EyeOff } from 'lucide-react';
import { decidePortfolioPhoto, getPortfolioPhotos, type PortfolioPhoto } from './api';
import { AdminPermission, Can } from '../auth/api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { DeskHeader, DeskNote, DeskPager, DeskRetry, Panel, SoftAction } from '../../design_system/Desk';
import { pageToShow } from '../../platform/api/query';

type Page = {
  items: PortfolioPhoto[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

function PhotoTile({ photo }: { photo: PortfolioPhoto }) {
  const [broken, setBroken] = useState(false);
  if (!photo.imageUrl || broken) {
    return (
      <span className="desk-photo__image desk-photo__image--empty" aria-hidden="true">
        <EyeOff size={44} strokeWidth={1.8} />
      </span>
    );
  }
  return (
    <img
      className="desk-photo__image"
      src={photo.imageUrl}
      alt={`صورة من معرض ${photo.provider.businessName}`}
      loading="lazy"
      onError={() => setBroken(true)}
    />
  );
}

export function PhotosPage() {
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const next = await getPortfolioPhotos({ status: 'PENDING', page, limit: 24 });
      // RA-AD-12: past the last page after its last photo was decided.
      const shown = pageToShow(page, next.totalPages);
      if (shown !== page) {
        setPage(shown);
        return;
      }
      setResult(next);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الصور.');
    }
  }, [page]);

  useEffect(() => {
    void load();
  }, [load]);

  async function approve(photo: PortfolioPhoto) {
    setBusyId(photo.id);
    setActionError(null);
    try {
      await decidePortfolioPhoto(photo.id, { decision: 'APPROVE' });
      await load();
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا نقبل الصورة.');
    } finally {
      setBusyId(null);
    }
  }

  async function decide(photo: PortfolioPhoto, decision: Parameters<typeof decidePortfolioPhoto>[1]) {
    setActionError(null);
    await decidePortfolioPhoto(photo.id, decision);
    await load();
  }

  return (
    <section>
      <DeskHeader title="صور تحتاج مراجعة" sub="كل صورة جديدة في معارض المزودين · الأقدم أول" />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {actionError ? <DeskRetry message={actionError} onRetry={() => void load()} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل الصور…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه صور تنتظر المراجعة.</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <ul className="desk-photos" aria-label="صور تحتاج مراجعة">
            {result.items.map((photo) => (
              <li key={photo.id} className="desk-photo">
                <PhotoTile photo={photo} />
                <strong>
                  {photo.album ? `${photo.provider.businessName} · ${photo.album}` : photo.provider.businessName}
                </strong>
                <small className={photo.forWomen ? 'desk-photo__flag' : undefined}>
                  {photo.forWomen ? 'للعرائس بس · المزود أكّد: بدون وجوه' : 'للعرسان والعرائس'}
                </small>
                <Can permission={AdminPermission.REVIEWS_WRITE}>
                  <span className="desk-actions">
                    <ConfirmDialog
                      variant="desk"
                      title={`شيل صورة من معرض ${photo.provider.businessName}`}
                      effects={[
                        'الصورة ما تظهر لأحد، وتنحذف من التخزين.',
                        'المزود يوصله إنها انشالت والسبب اللي تكتبه.',
                      ]}
                      needsNote
                      noteLabel="ليش انشالت؟ (يقرأه المزود)"
                      confirmLabel="شِل"
                      confirmTone="coral"
                      trigger={<SoftAction tone="coral">شِل</SoftAction>}
                      onConfirm={(reason) => decide(photo, { decision: 'REJECT', reason })}
                    />
                    {photo.forWomen ? (
                      <ConfirmDialog
                        variant="desk"
                        title="صورة من «حفلات النساء»"
                        effects={[
                          'تأكدت إن ما فيها أي وجه، ولا انعكاس وجه.',
                          'تظهر للعرائس بس.',
                        ]}
                        confirmLabel="سليمة، ما فيها وجوه"
                        confirmTone="green"
                        trigger={<SoftAction tone="green">سليمة</SoftAction>}
                        onConfirm={() => decide(photo, { decision: 'APPROVE', noFacesChecked: true })}
                      />
                    ) : (
                      <SoftAction
                        tone="green"
                        disabled={busyId === photo.id}
                        onClick={() => void approve(photo)}
                      >
                        سليمة
                      </SoftAction>
                    )}
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
      <DeskNote>الصورة ما تظهر للعرسان لين تتراجع. والمزود يوصله ليش انشالت.</DeskNote>
    </section>
  );
}
