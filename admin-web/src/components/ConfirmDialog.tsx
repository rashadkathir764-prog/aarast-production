import { ReactNode, useState } from 'react';
import { createPortal } from 'react-dom';

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

  function closeDialog() {
    if (isSubmitting) return;
    setOpen(false);
    setNote('');
  }

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
      <span className="dialog-trigger" onClick={() => setOpen(true)}>
        {trigger}
      </span>
      {open
        ? createPortal(
            <div
              className="dialog-backdrop"
              role="presentation"
              onClick={closeDialog}
            >
              <div
                className="dialog"
                role="dialog"
                aria-modal="true"
                onClick={(event) => event.stopPropagation()}
              >
                <div className={`dialog__mark ${tone}`} aria-hidden="true" />
                <h2>{title}</h2>
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
                  <button
                    className="button button--ghost"
                    type="button"
                    onClick={closeDialog}
                  >
                    إلغاء
                  </button>
                  <button
                    className={`button ${tone === 'danger' ? 'button--danger' : ''}`}
                    type="button"
                    onClick={submit}
                    disabled={isSubmitting || (needsNote && !note.trim())}
                  >
                    {isSubmitting ? 'جاري التنفيذ...' : confirmLabel}
                  </button>
                </div>
              </div>
            </div>,
            document.body,
          )
        : null}
    </>
  );
}
