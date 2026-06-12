import { ReactNode, useState } from 'react';

type ConfirmDialogProps = {
  title: string;
  message: string;
  confirmLabel: string;
  tone?: 'normal' | 'danger';
  needsNote?: boolean;
  noteLabel?: string;
  trigger: ReactNode;
  onConfirm: (note: string) => Promise<void> | void;
};

export function ConfirmDialog({
  title,
  message,
  confirmLabel,
  tone = 'normal',
  needsNote = false,
  noteLabel = 'الملاحظة',
  trigger,
  onConfirm,
}: ConfirmDialogProps) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function submit() {
    if (needsNote && !note.trim()) return;
    setIsSubmitting(true);
    try {
      await onConfirm(note.trim());
      setOpen(false);
      setNote('');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <>
      <span onClick={() => setOpen(true)}>{trigger}</span>
      {open ? (
        <div className="dialog-backdrop" role="presentation">
          <div className="dialog" role="dialog" aria-modal="true">
            <h3>{title}</h3>
            <p>{message}</p>
            {needsNote ? (
              <label className="form-field">
                <span>{noteLabel}</span>
                <textarea
                  value={note}
                  onChange={(event) => setNote(event.target.value)}
                  rows={4}
                />
              </label>
            ) : null}
            <div className="dialog-actions">
              <button className="button ghost" onClick={() => setOpen(false)}>
                إلغاء
              </button>
              <button
                className={`button ${tone === 'danger' ? 'danger' : ''}`}
                onClick={submit}
                disabled={isSubmitting || (needsNote && !note.trim())}
              >
                {isSubmitting ? 'جاري التنفيذ...' : confirmLabel}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
