import { useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import { AuthContext } from './AuthContext';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [role, setRole] = useState<'vendor' | 'customer' | null>(null);
  const [loading, setLoading] = useState(true);
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    let mounted = true;

    async function initAuth() {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (mounted) setSession(session);
      } catch (e) {
        if (mounted) console.error(e);
      } finally {
        if (mounted) setIsInitialized(true);
      }
    }
    
    initAuth();

    const { data: listener } = supabase.auth.onAuthStateChange((_event, newSession) => {
      if (mounted) setSession(newSession);
    });

    return () => {
      mounted = false;
      if (listener?.subscription) {
        listener.subscription.unsubscribe();
      }
    };
  }, []);

  useEffect(() => {
    let mounted = true;

    async function loadRole() {
      if (!isInitialized) return;

      if (!session?.user) {
        if (mounted) {
          setRole(null);
          setLoading(false);
        }
        return;
      }

      if (mounted) setLoading(true);

      try {
        const { data: userRole, error } = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', session.user.id)
          .single();
          
        if (mounted) {
          if (error) {
            console.error('Failed to load user role', error);
            setRole(null);
          } else {
            setRole(userRole?.role === 'vendor' ? 'vendor' : 'customer');
          }
        }
      } catch (err) {
        if (mounted) {
          console.error(err);
          setRole(null);
        }
      } finally {
        if (mounted) setLoading(false);
      }
    }

    loadRole();

    return () => {
      mounted = false;
    };
  }, [session?.user, isInitialized]);

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    return { error: error?.message ?? null };
  };

  const signUp = async (email: string, password: string) => {
    const redirectUrl = `${window.location.origin}${import.meta.env.BASE_URL}`;
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: redirectUrl,
      },
    });
    return { error: error?.message ?? null };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <AuthContext.Provider value={{ session, user: session?.user ?? null, role, loading, signIn, signUp, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}
