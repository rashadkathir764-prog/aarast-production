import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ConfirmDialog } from './ConfirmDialog';

// RA-AD-19: these three tested a «classic» look no page used; every dialog
// in the panel is the desk one, so they test that.
describe('ConfirmDialog', () => {
  it('traps focus, closes with Escape, and restores the trigger focus', async () => {
    render(
      <ConfirmDialog        title="Confirm"
        confirmLabel="Confirm"
        trigger={<button type="button">Open</button>}
        onConfirm={() => undefined}
      />,
    );

    const trigger = screen.getByRole('button', { name: 'Open' });
    fireEvent.click(trigger);

    const confirm = screen.getByRole('button', { name: 'Confirm' });
    const cancel = screen.getByRole('button', { name: 'تراجع' });
    await waitFor(() => expect(confirm).toHaveFocus());

    cancel.focus();
    fireEvent.keyDown(document, { key: 'Tab' });
    expect(confirm).toHaveFocus();

    confirm.focus();
    fireEvent.keyDown(document, { key: 'Tab', shiftKey: true });
    expect(cancel).toHaveFocus();

    fireEvent.keyDown(document, { key: 'Escape' });
    await waitFor(() =>
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument(),
    );
    expect(trigger).toHaveFocus();
  });

  it('keeps the dialog locked while confirmation is pending', async () => {
    let resolveConfirmation!: () => void;
    const onConfirm = vi.fn(
      () =>
        new Promise<void>((resolve) => {
          resolveConfirmation = resolve;
        }),
    );

    render(
      <ConfirmDialog        title="Confirm"
        confirmLabel="Confirm"
        trigger={<button type="button">Open</button>}
        onConfirm={onConfirm}
      />,
    );

    const trigger = screen.getByRole('button', { name: 'Open' });
    fireEvent.click(trigger);
    fireEvent.click(screen.getByRole('button', { name: 'Confirm' }));

    const dialog = screen.getByRole('dialog');
    await waitFor(() =>
      expect(screen.getByRole('button', { name: 'لحظة…' })).toBeDisabled(),
    );
    expect(screen.getByRole('button', { name: 'تراجع' })).toBeDisabled();

    fireEvent.keyDown(document, { key: 'Escape' });
    fireEvent.click(dialog.parentElement!);
    expect(screen.getByRole('dialog')).toBeInTheDocument();

    await act(async () => resolveConfirmation());
    await waitFor(() =>
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument(),
    );
    expect(trigger).toHaveFocus();
  });

  // RA-AD-16: the box took any length, and a note past the server's limit
  // came back as «راجع البيانات المدخلة» with the typed note still there.
  it('holds the note to the length the server takes', () => {
    render(
      <ConfirmDialog        title="شيل الصورة"
        confirmLabel="شِل"
        needsNote
        noteLabel="السبب"
        noteMaxLength={400}
        trigger={<button type="button">Open</button>}
        onConfirm={() => undefined}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: 'Open' }));
    expect(screen.getByLabelText('السبب')).toHaveAttribute('maxlength', '400');
  });

  it('renders a rejected mutation instead of leaking an unhandled promise', async () => {
    const onConfirm = vi.fn().mockRejectedValue(new Error('mutation failed'));

    render(
      <ConfirmDialog        title="Confirm"
        confirmLabel="Confirm"
        trigger={<button type="button">Open</button>}
        onConfirm={onConfirm}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Open' }));
    fireEvent.click(screen.getByRole('button', { name: 'Confirm' }));

    await waitFor(() =>
      expect(screen.getByRole('alert')).toHaveTextContent('mutation failed'),
    );
    expect(onConfirm).toHaveBeenCalledWith('');
  });
});
