import { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { DeskNote } from '../../design_system/Desk';
import { useAuth } from './AuthProvider';
import '../../styles/desk.css';

export function RequireAdmin({ children }: { children: ReactNode }) {
  const { user, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    // The desk kit's outside frame while the session is restored (D56).
    return (
      <main className="desk-gate" aria-busy="true">
        <DeskNote>لحظة، نتأكد من دخولك…</DeskNote>
      </main>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  return <>{children}</>;
}
