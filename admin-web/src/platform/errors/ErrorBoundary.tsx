import { Component, ReactNode } from 'react';

type Props = {
  children: ReactNode;
};

type State = {
  error: Error | null;
};

/**
 * Catches render-time exceptions anywhere below it so a single broken
 * page shows a recoverable message instead of a blank white screen.
 * React only routes errors to class components, so this stays a class.
 */
export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error): void {
    // Surfaced for the browser console / any attached logger. The admin
    // panel has no Sentry wiring, so this is the audit trail.
    console.error('Admin panel crashed:', error);
  }

  private handleReload = (): void => {
    this.setState({ error: null });
    window.location.assign('/');
  };

  render(): ReactNode {
    if (this.state.error) {
      return (
        <div dir="rtl" className="error-boundary" role="alert">
          <h1>حدث خطأ غير متوقع</h1>
          <p>
            تعذر عرض هذه الصفحة. تم تسجيل الخطأ. يمكنك العودة إلى لوحة
            التحكم والمحاولة مرة أخرى.
          </p>
          <button type="button" onClick={this.handleReload}>
            العودة إلى لوحة التحكم
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
