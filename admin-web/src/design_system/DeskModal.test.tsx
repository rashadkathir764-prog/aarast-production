import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { ConfirmDialog } from './ConfirmDialog';
import { DeskModal } from './DeskModal';

// RA-AD-02: every catalog page keeps its draft in page state and passes an
// inline onClose, so each keystroke re-rendered the window with a new
// onClose. Focus then went back to the opener and on to the window's first
// control, the × button: the next letters were lost and a space closed it.
function EditCity({ onClosed = () => undefined }: { onClosed?: () => void }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>
        عدّل
      </button>
      <DeskModal
        title="عدّل مدينة"
        open={open}
        onClose={() => {
          setOpen(false);
          onClosed();
        }}
      >
        <label>
          الاسم
          <input value={name} onChange={(event) => setName(event.target.value)} />
        </label>
      </DeskModal>
    </>
  );
}

function openEditor(onClosed?: () => void) {
  render(<EditCity onClosed={onClosed} />);
  const opener = screen.getByRole('button', { name: 'عدّل' });
  opener.focus();
  fireEvent.click(opener);
  return opener;
}

describe('DeskModal', () => {
  it('opens on its first field, not on ×', () => {
    openEditor();
    expect(document.activeElement).toBe(screen.getByLabelText('الاسم'));
  });

  it('keeps the focus in the field the admin types in', () => {
    openEditor();
    const field = screen.getByLabelText('الاسم');
    field.focus();
    for (const value of ['ق', 'قا', 'قاع', 'قاعة']) {
      fireEvent.change(field, { target: { value } });
      expect(document.activeElement).toBe(field);
    }
    expect(screen.getByLabelText('الاسم')).toHaveValue('قاعة');
  });

  it('still closes on Escape with the latest onClose', () => {
    const onClosed = vi.fn();
    openEditor(onClosed);
    fireEvent.change(screen.getByLabelText('الاسم'), { target: { value: 'عدن' } });
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  // RA-AD-19: «عطّل المدينة» opens a confirm dialog over the edit window;
  // Escape closed both, and the draft with them. It closes the one on top.
  it('lets Escape close the dialog on top first, then the window', async () => {
    const onClosed = vi.fn();
    render(
      <DeskModal title="عدّل مدينة" open onClose={onClosed}>
        <ConfirmDialog          title="تعطيل عدن"
          confirmLabel="عطّلها"
          trigger={<button type="button">عطّل المدينة</button>}
          onConfirm={() => undefined}
        />
      </DeskModal>,
    );
    fireEvent.click(screen.getByRole('button', { name: 'عطّل المدينة' }));
    fireEvent.keyDown(document, { key: 'Escape' });
    await waitFor(() =>
      expect(screen.queryByRole('dialog', { name: 'تعطيل عدن' })).not.toBeInTheDocument(),
    );
    expect(onClosed).not.toHaveBeenCalled();
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(onClosed).toHaveBeenCalledTimes(1);
  });

  it('gives the focus back to the opener when it closes', () => {
    const opener = openEditor();
    expect(document.activeElement).not.toBe(opener);
    fireEvent.change(screen.getByLabelText('الاسم'), { target: { value: 'تعز' } });
    fireEvent.click(screen.getByRole('button', { name: 'سكّر' }));
    expect(document.activeElement).toBe(opener);
  });
});
