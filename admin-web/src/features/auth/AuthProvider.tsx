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
  AdminLoginChallenge,
  AdminUser,
  completeAdminLogin,
  logoutAdmin,
  restoreAdminSession,
  startAdminLogin,
} from './transport';
import { setAdminSessionExpiredHandler } from '../../platform/api/client';

type AuthContextValue = {
  user: AdminUser | null;
  isLoading: boolean;
  error: string | null;
  challenge: AdminLoginChallenge | null;
  login: (phone: string, password: string) => Promise<void>;
  verifyMfa: (code: string) => Promise<void>;
  cancelMfa: () => void;
  logout: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [challenge, setChallenge] = useState<AdminLoginChallenge | null>(null);

  useEffect(() => {
    setAdminSessionExpiredHandler(() => {
      setUser(null);
      setChallenge(null);
      setError('انتهت جلسة الإدارة. سجّل الدخول مرة أخرى.');
      setIsLoading(false);
    });

    return () => {
      setAdminSessionExpiredHandler(null);
    };
  }, []);

  useEffect(() => {
    let isMounted = true;
    async function loadCurrentUser() {
      try {
        const currentUser = await restoreAdminSession();
        if (isMounted) setUser(currentUser);
      } catch {
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
      const next = await startAdminLogin(phone, password);
      if ('user' in next) {
        // A remembered device: signed in without a code.
        setChallenge(null);
        setUser(next.user);
      } else {
        setChallenge(next);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تسجيل الدخول.');
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const verifyMfa = useCallback(async (code: string) => {
    if (!challenge) throw new Error('ابدأ تسجيل الدخول أولًا.');
    setIsLoading(true);
    setError(null);
    try {
      const loggedInUser = await completeAdminLogin(
        challenge.challengeToken,
        code,
      );
      setUser(loggedInUser);
      setChallenge(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر التحقق بخطوتين.');
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, [challenge]);

  const cancelMfa = useCallback(() => {
    setChallenge(null);
    setError(null);
  }, []);

  const logout = useCallback(async () => {
    try {
      await logoutAdmin();
    } finally {
      setUser(null);
      setChallenge(null);
      setError(null);
    }
  }, []);

  const value = useMemo(
    () => ({
      user,
      isLoading,
      error,
      challenge,
      login,
      verifyMfa,
      cancelMfa,
      logout,
    }),
    [
      user,
      isLoading,
      error,
      challenge,
      login,
      verifyMfa,
      cancelMfa,
      logout,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider');
  return value;
}
