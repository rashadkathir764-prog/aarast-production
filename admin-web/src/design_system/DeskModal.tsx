import { type ReactNode, useEffect, useId, useRef } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';

/**
 * A desk window for forms (add a listed provider, import a file, edit a
 * category): the confirm dialog's frame, closed by Escape, the backdrop or ×.
 */
export function DeskModal({
  title,
  open,
  onClose,
  children,
  wide,
}: {
  title: string;
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  wide?: boolean;
}) {
  const titleId = `desk-modal-${useId().replace(/:/g, '')}`;
  const ref = useRef<HTMLDivElement>(null);
  const opener = useRef<Element | null>(null);
  // RA-AD-02: the pages pass a new onClose on every render (their draft is
  // page state). The window reads the latest one and runs its focus work on
  // opening and closing only, never on a keystroke.
  const close = useRef(onClose);
  close.current = onClose;

  useEffect(() => {
    if (!open) return undefined;
    opener.current = document.activeElement;
    const box = ref.current;
    // The first field of the form, not the × that comes before it.
    const first =
      box?.querySelector<HTMLElement>(
        'input:not([disabled]), select:not([disabled]), textarea:not([disabled])',
      ) ?? box?.querySelector<HTMLElement>('button:not([disabled])');
    (first ?? box)?.focus();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        close.current();
      }
    };
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('keydown', onKey);
      if (opener.current instanceof HTMLElement) opener.current.focus();
    };
  }, [open]);

  if (!open) return null;
  return createPortal(
    <div className="desk-dialog-backdrop" role="presentation" onClick={onClose}>
      <div
        className={`desk-dialog${wide ? ' desk-dialog--wide' : ''}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        ref={ref}
        tabIndex={-1}
        dir="rtl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="desk-dialog__head">
          <h2 id={titleId}>{title}</h2>
          <button className="desk-dialog__close" type="button" aria-label="سكّر" onClick={onClose}>
            <X size={20} aria-hidden="true" />
          </button>
        </div>
        {children}
      </div>
    </div>,
    document.body,
  );
}
