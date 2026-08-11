import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ConfirmDialog } from './ConfirmDialog';

describe('ConfirmDialog', () => {
  it('traps focus, closes with Escape, and restores the trigger focus', async () => {
    render(
      <ConfirmDialog
        title="Confirm"
        message="Continue?"
        confirmLabel="Confirm"
        trigger={<button type="button">Open</button>}
        onConfirm={() => undefined}
      />,
    );

    const trigger = screen.getByRole('button', { name: 'Open' });
    fireEvent.click(trigger);

    const cancel = screen.getByRole('button', { name: 'إلغاء' });
    const confirm = screen.getByRole('button', { name: 'Confirm' });
    await waitFor(() => expect(cancel).toHaveFocus());

    confirm.focus();
    fireEvent.keyDown(document, { key: 'Tab' });
    expect(cancel).toHaveFocus();

    cancel.focus();
    fireEvent.keyDown(document, { key: 'Tab', shiftKey: true });
    expect(confirm).toHaveFocus();

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
      <ConfirmDialog
        title="Confirm"
        message="Continue?"
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
      expect(screen.getByRole('button', { name: 'جاري التنفيذ...' })).toBeDisabled(),
    );
    expect(screen.getByRole('button', { name: 'إلغاء' })).toBeDisabled();

    fireEvent.keyDown(document, { key: 'Escape' });
    fireEvent.click(dialog.parentElement!);
    expect(screen.getByRole('dialog')).toBeInTheDocument();

    await act(async () => resolveConfirmation());
    await waitFor(() =>
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument(),
    );
    expect(trigger).toHaveFocus();
  });

  it('renders a rejected mutation instead of leaking an unhandled promise', async () => {
    const onConfirm = vi.fn().mockRejectedValue(new Error('mutation failed'));

    render(
      <ConfirmDialog
        title="Confirm"
        message="Continue?"
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
