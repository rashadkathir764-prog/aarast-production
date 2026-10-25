import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ErrorBoundary } from './ErrorBoundary';

function Boom(): never {
  throw new Error('render failure');
}

describe('ErrorBoundary', () => {
  it('renders children when nothing throws', () => {
    render(
      <ErrorBoundary>
        <p>محتوى سليم</p>
      </ErrorBoundary>,
    );
    expect(screen.getByText('محتوى سليم')).toBeInTheDocument();
  });

  it('shows the recovery UI when a child throws', () => {
    // React logs the caught error; silence it for a clean test run.
    const consoleError = vi
      .spyOn(console, 'error')
      .mockImplementation(() => undefined);

    render(
      <ErrorBoundary>
        <Boom />
      </ErrorBoundary>,
    );

    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(screen.getByText('حدث خطأ غير متوقع')).toBeInTheDocument();
    // The desk's home is «الصندوق» (n01); «لوحة التحكم» was retired.
    expect(screen.getByRole('button', { name: 'ارجع للصندوق' })).toBeInTheDocument();

    consoleError.mockRestore();
  });
});
