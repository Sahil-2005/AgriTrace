import React from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { Navigate, useLocation } from 'react-router-dom';
import { Loader2 } from 'lucide-react';

interface ProtectedRouteProps {
  children: React.ReactNode;
  allowedUserTypes?: string[];
}

export const ProtectedRoute = ({ children, allowedUserTypes }: ProtectedRouteProps) => {
  const { user, profile, loading } = useAuth();
  const location = useLocation();
  const [profileLoading, setProfileLoading] = React.useState(true);

  // Wait a bit for profile to load if user exists but profile doesn't
  React.useEffect(() => {
    if (user && !profile && !loading) {
      // Give profile a chance to load (profile loads asynchronously)
      const timer = setTimeout(() => {
        setProfileLoading(false);
      }, 1000); // Wait 1 second for profile to load
      return () => clearTimeout(timer);
    } else {
      setProfileLoading(false);
    }
  }, [user, profile, loading]);

  if (loading || profileLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="h-8 w-8 animate-spin mx-auto mb-4" />
          <p>Loading...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Priority: 1. Profile from database, 2. User metadata, 3. Email fallback
  const userTypeFromProfile = profile?.user_type;
  const userTypeFromMetadata = user.user_metadata?.user_type;
  
  // Use profile first (most reliable), then metadata, then fallback
  let effectiveUserType = userTypeFromProfile || userTypeFromMetadata;
  
  if (!effectiveUserType) {
    // Check email to determine user type (temporary fallback)
    if (user?.email === 'realjarirkhann@gmail.com') {
      effectiveUserType = 'distributor';
    } else if (user?.email === 'kjarir23@gmail.com') {
      effectiveUserType = 'farmer';
    } else {
      // Default to farmer for any other users without user_type
      effectiveUserType = 'farmer';
    }
  }
  
  // Log for debugging
  console.log('🔐 ProtectedRoute check:', {
    path: location.pathname,
    effectiveUserType,
    allowedUserTypes,
    fromProfile: userTypeFromProfile,
    fromMetadata: userTypeFromMetadata,
    profileExists: !!profile,
    profileId: profile?.id,
    userEmail: user?.email
  });
  
  // Check if user type is allowed
  if (allowedUserTypes && allowedUserTypes.length > 0) {
    if (!effectiveUserType || !allowedUserTypes.includes(effectiveUserType)) {
      console.error('🚫 Access denied:', {
        effectiveUserType,
        allowedUserTypes,
        fromProfile: userTypeFromProfile,
        fromMetadata: userTypeFromMetadata,
        profile: profile,
        path: location.pathname
      });
      return <Navigate to="/unauthorized" replace />;
    }
  }

  console.log('✅ Access granted:', { effectiveUserType, allowedUserTypes });
  return <>{children}</>;
};
