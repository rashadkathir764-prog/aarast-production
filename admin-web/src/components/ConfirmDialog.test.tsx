import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ConfirmDialog } from './ConfirmDialog';

describe('ConfirmDialog mutation errors', () => {
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
