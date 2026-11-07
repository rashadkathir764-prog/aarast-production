import {
  cloneElement,
  isValidElement,
  type KeyboardEvent as ReactKeyboardEvent,
  type MouseEvent as ReactMouseEvent,
  type ReactElement,
  type ReactNode,
  useEffect,
  useId,
  useRef,
  useState,
} from 'react';
import { createPortal } from 'react-dom';
import { isTopWindow } from './DeskModal';

type TriggerProps = {
  onClick?: (event: ReactMouseEvent<HTMLElement>) => void;
  'aria-haspopup'?: string;
  'aria-expanded'?: boolean;
  'aria-controls'?: string;
};

/**
 * A dialog that takes a note says how long the server lets it be (RA-AD-16):
 * the `MaxLength` of the field in the request it sends.
 */
type NoteProps =
  | { needsNote?: false; noteMaxLength?: never }
  | { needsNote: true; noteMaxLength: number };

/**
 * The admin desk dialog (akit `confirm`): what will happen as dotted lines,
 * the note in a teal box, the action first and «تراجع» after it. The only
 * look the panel uses (RA-AD-19 removed an older one no page called).
 */
type ConfirmDialogProps = NoteProps & {
  title: string;
  confirmLabel: string;
  noteLabel?: string;
  trigger: ReactNode;
  onConfirm: (note: string) => Promise<void> | void;
  effects?: string[];
  confirmTone?: 'teal' | 'coral' | 'green' | 'saffron';
  cancelLabel?: string;
  noteRequired?: boolean;
  /** The note the box opens with (the one the reader sees now); empty by default. */
  initialNote?: string;
  /** Words for a refused action; the error's own message by default. */
  describeError?: (error: unknown) => string;
};

export function ConfirmDialog({
  title,
  confirmLabel,
  needsNote = false,
  noteMaxLength,
  noteLabel = 'الملاحظة',
  trigger,
  onConfirm,
  effects,
  confirmTone = 'teal',
  cancelLabel = 'تراجع',
  noteRequired = true,
  initialNote = '',
  describeError,
}: ConfirmDialogProps) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const reactId = useId();
  const dialogId = `confirm-dialog-${reactId.replace(/:/g, '')}`;
  const titleId = `${dialogId}-title`;
  const effectsId = `${dialogId}-effects`;
  const dialogRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLElement | null>(null);
  const wasOpenRef = useRef(false);
  const isSubmittingRef = useRef(false);

  useEffect(() => {
    isSubmittingRef.current = isSubmitting;
  }, [isSubmitting]);

  useEffect(() => {
    if (!open) {
      if (wasOpenRef.current) {
        triggerRef.current?.focus();
        triggerRef.current = null;
        wasOpenRef.current = false;
      }
      return;
    }

    wasOpenRef.current = true;
    const activeDialog = dialogRef.current;
    if (!activeDialog) return;

    const focusable = activeDialog.querySelector<HTMLElement>(
      'button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [href], [tabindex]:not([tabindex="-1"])',
    );
    (focusable ?? activeDialog).focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        if (!isTopWindow(activeDialog)) return;
        event.preventDefault();
        if (!isSubmittingRef.current) closeDialog();
        return;
      }

      if (event.key !== 'Tab') return;
      const controls = Array.from(
        activeDialog.querySelectorAll<HTMLElement>(
          'button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [href], [tabindex]:not([tabindex="-1"])',
        ),
      );
      if (controls.length === 0) {
        event.preventDefault();
        activeDialog.focus();
        return;
      }

      const first = controls[0];
      const last = controls[controls.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [open]);

  function closeDialog() {
    if (isSubmitting) return;
    setOpen(false);
    setNote('');
    setError(null);
  }

  const noteMissing = needsNote && noteRequired && !note.trim();

  async function submit() {
    if (noteMissing) return;
    setIsSubmitting(true);
    setError(null);
    try {
      await onConfirm(note.trim());
      setOpen(false);
      setNote('');
    } catch (value) {
      setError(
        describeError
          ? describeError(value)
          : value instanceof Error
            ? value.message
            : 'تعذر تنفيذ الإجراء الإداري.',
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  function openDialog(event: ReactMouseEvent<HTMLElement>) {
    triggerRef.current = event.currentTarget;
    setError(null);
    setNote(initialNote);
    setOpen(true);
  }

  function handleFallbackTriggerKeyDown(event: ReactKeyboardEvent<HTMLSpanElement>) {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    openDialog(event as unknown as ReactMouseEvent<HTMLElement>);
  }

  const triggerElement = isValidElement(trigger)
    ? cloneElement(trigger as ReactElement<TriggerProps>, {
        'aria-haspopup': 'dialog',
        'aria-expanded': open,
        'aria-controls': open ? dialogId : undefined,
        onClick: (event) => {
          trigger.props.onClick?.(event);
          if (!event.defaultPrevented) openDialog(event);
        },
      })
    : (
        <span
          className="dialog-trigger"
          role="button"
          tabIndex={0}
          aria-haspopup="dialog"
          aria-expanded={open}
          aria-controls={open ? dialogId : undefined}
          onClick={openDialog}
          onKeyDown={handleFallbackTriggerKeyDown}
        >
          {trigger}
        </span>
      );

  return (
    <>
      {triggerElement}
      {open
        ? createPortal(
            <div
              className="desk-dialog-backdrop"
              role="presentation"
              onClick={closeDialog}
            >
              <div
                className="desk-dialog"
                role="dialog"
                aria-modal="true"
                aria-labelledby={titleId}
                aria-describedby={effectsId}
                id={dialogId}
                ref={dialogRef}
                tabIndex={-1}
                dir="rtl"
                onClick={(event) => event.stopPropagation()}
              >
                <h2 id={titleId}>{title}</h2>
                <div id={effectsId}>
                  {effects && effects.length > 0 ? (
                    <ul className="desk-dialog__effects">
                      {effects.map((effect) => (
                        <li key={effect}>{effect}</li>
                      ))}
                    </ul>
                  ) : null}
                </div>
                {needsNote ? (
                  <label className="desk-dialog__note">
                    <span>{noteLabel}</span>
                    <textarea
                      value={note}
                      onChange={(event) => setNote(event.target.value)}
                      maxLength={noteMaxLength}
                      rows={1}
                    />
                  </label>
                ) : null}
                {error ? (
                  <p className="desk-dialog__error" role="alert">
                    {error}
                  </p>
                ) : null}
                <div className="desk-dialog__actions">
                  <button
                    className={`desk-btn desk-btn--${confirmTone}`}
                    type="button"
                    onClick={submit}
                    disabled={isSubmitting || noteMissing}
                  >
                    <span>{isSubmitting ? 'لحظة…' : confirmLabel}</span>
                  </button>
                  <button
                    className="desk-btn desk-btn--soft"
                    type="button"
                    onClick={closeDialog}
                    disabled={isSubmitting}
                  >
                    <span>{cancelLabel}</span>
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
