import { useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';

export function Topbar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  return (
    <header className="topbar">
      <div>
        <p>مرحباً</p>
        <h1>{user?.name ?? 'مسؤول أعّرست'}</h1>
      </div>
      <button className="button ghost" onClick={handleLogout}>
        تسجيل الخروج
      </button>
    </header>
  );
}
