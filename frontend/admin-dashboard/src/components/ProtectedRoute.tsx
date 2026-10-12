import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';

export function ProtectedRoute() {
  const { ready, user } = useAuth();
  const location = useLocation();
  if (!ready) return <div className="loading-page"><div><div className="loading-mark" /><span>Restoring secure session</span></div></div>;
  return user ? <Outlet /> : <Navigate to="/login" replace state={{ from: location }} />;
}

export function AdminRoute() {
  const { isAdmin } = useAuth();
  return isAdmin ? <Outlet /> : <Navigate to="/access-denied" replace />;
}
