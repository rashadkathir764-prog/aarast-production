import { Component, ReactNode } from 'react';
import '../../styles/desk.css';

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
      // The desk kit's outside frame (D56); «الصندوق» is the desk's home.
      return (
        <main dir="rtl" className="desk-gate" role="alert">
          <section className="desk-panel desk-gate__card">
            <h1 className="desk-gate__title">حدث خطأ غير متوقع</h1>
            <p className="desk-note">
              ما قدرنا نعرض هذه الصفحة، وانسجل الخطأ. ارجع للصندوق وجرّب مرة ثانية.
            </p>
            <button
              type="button"
              className="desk-btn desk-btn--teal desk-btn--full"
              onClick={this.handleReload}
            >
              ارجع للصندوق
            </button>
          </section>
        </main>
      );
    }

    return this.props.children;
  }
}
