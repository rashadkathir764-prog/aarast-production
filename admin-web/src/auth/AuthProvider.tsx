import {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import {
  AdminUser,
  clearAdminToken,
  fetchMe,
  getAdminToken,
  loginAdmin,
} from '../api/auth';

type AuthContextValue = {
  user: AdminUser | null;
  isLoading: boolean;
  error: string | null;
  login: (phone: string, password: string) => Promise<void>;
  logout: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    async function loadCurrentUser() {
      if (!getAdminToken()) {
        if (isMounted) setIsLoading(false);
        return;
      }

      try {
        const currentUser = await fetchMe();
        if (currentUser.role !== 'ADMIN') {
          clearAdminToken();
          if (isMounted) setUser(null);
          return;
        }
        if (isMounted) setUser(currentUser);
      } catch {
        clearAdminToken();
        if (isMounted) setUser(null);
      } finally {
        if (isMounted) setIsLoading(false);
      }
    }

    loadCurrentUser();
    return () => {
      isMounted = false;
    };
  }, []);

  const login = useCallback(async (phone: string, password: string) => {
    setIsLoading(true);
    setError(null);
    try {
      const loggedInUser = await loginAdmin(phone, password);
      setUser(loggedInUser);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تسجيل الدخول.');
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const logout = useCallback(() => {
    clearAdminToken();
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({ user, isLoading, error, login, logout }),
    [user, isLoading, error, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider');
  return value;
}
