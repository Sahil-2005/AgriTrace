import React, { createContext, useContext, useEffect, useState } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';

interface Profile {
  id: string;
  user_id: string;
  full_name: string;
  email: string;
  user_type: 'farmer' | 'distributor' | 'retailer' | 'helper' | 'admin';
  farm_location?: string;
  wallet_address?: string;
}

interface AuthContextType {
  user: User | null;
  session: Session | null;
  profile: Profile | null;
  loading: boolean;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Set up auth state listener
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        console.log('🔍 Auth state change:', event, session?.user?.id);
        setSession(session);
        setUser(session?.user ?? null);
        
        // Set loading to false immediately for auth
        setLoading(false);
        
        // Fetch profile asynchronously (don't block auth)
        if (session?.user) {
          fetchProfile(session.user.id);
        } else {
          setProfile(null);
        }
      }
    );

    // Check for existing session
    supabase.auth.getSession().then(({ data: { session } }) => {
      console.log('🔍 Initial session check:', session?.user?.id);
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false); // Set loading to false immediately
      
      // Fetch profile asynchronously if user exists
      if (session?.user) {
        fetchProfile(session.user.id);
      } else {
        setProfile(null);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  // Separate function to fetch profile without blocking auth
  const fetchProfile = async (userId: string) => {
    try {
      console.log('🔍 Fetching profile for user:', userId);
      
      // First, try to get the user's auth data to extract metadata
      const { data: { user } } = await supabase.auth.getUser();
      
      // Try to fetch existing profile - use limit(1) to avoid single() error
      const { data: profileList, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('user_id', userId)
        .limit(1);
      
      if (error) {
        console.warn('Error fetching profile:', error.message);
        setProfile(null);
        return;
      }
      
      // If profile exists, use it
      if (profileList && profileList.length > 0) {
        console.log('✅ Profile loaded:', profileList[0]);
        setProfile(profileList[0]);
        return;
      }
      
      // Profile doesn't exist - create it from user metadata
      console.log('⚠️ Profile not found, creating from user metadata...');
      
      if (user) {
        // Normalize user_type (fix typos and ensure valid values)
        const rawUserType = (user.user_metadata?.user_type || '').toLowerCase();
        const normalizedUserType = 
          rawUserType === 'distirbutor' || rawUserType === 'distributer' ? 'distributor' :
          ['farmer', 'distributor', 'retailer', 'helper', 'admin'].includes(rawUserType) ? rawUserType :
          'farmer'; // Default to farmer
        
        // Normalize role (use role from metadata if valid, otherwise use user_type)
        const rawRole = (user.user_metadata?.role || '').toLowerCase();
        const normalizedRole = 
          rawRole === 'distirbutor' || rawRole === 'distributer' ? 'distributor' :
          ['farmer', 'distributor', 'retailer', 'helper', 'admin'].includes(rawRole) ? rawRole :
          normalizedUserType; // Fallback to normalized user_type
        
        const newProfile = {
          user_id: userId,
          full_name: user.user_metadata?.full_name || user.email?.split('@')[0] || 'User',
          email: user.email || '',
          user_type: normalizedUserType,
          farm_location: user.user_metadata?.farm_location || null,
          role: normalizedRole, // Ensure role is set and matches user_type
        };
        
        const { data: createdProfile, error: createError } = await supabase
          .from('profiles')
          .insert(newProfile)
          .select()
          .single();
        
        if (createError) {
          console.error('❌ Failed to create profile:', createError);
          setProfile(null);
        } else {
          console.log('✅ Profile created:', createdProfile);
          setProfile(createdProfile);
        }
      } else {
        console.warn('User data not available to create profile');
        setProfile(null);
      }
    } catch (error) {
      console.error('Error fetching profile:', error);
      setProfile(null);
    }
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  const value = {
    user,
    session,
    profile,
    loading,
    signOut,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}