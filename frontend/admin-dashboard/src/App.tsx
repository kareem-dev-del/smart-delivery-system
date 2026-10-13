import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthProvider';
import { AppLayout } from './components/AppLayout';
import { AdminRoute, ProtectedRoute } from './components/ProtectedRoute';
import { AccessDeniedPage } from './pages/AccessDeniedPage';
import { ComingNextPage } from './pages/ComingNextPage';
import { DashboardPage } from './pages/DashboardPage';
import { LoginPage } from './pages/LoginPage';
import { NotFoundPage } from './pages/NotFoundPage';
import { OrdersPage } from './pages/OrdersPage';
import { OrderDetailsPage } from './pages/OrderDetailsPage';

function IndexRedirect() {
  const { user, isAdmin, ready } = useAuth();
  if (!ready) return <div className="loading-page"><div><div className="loading-mark" /><span>Preparing workspace</span></div></div>;
  return <Navigate to={user ? (isAdmin ? '/dashboard' : '/access-denied') : '/login'} replace />;
}

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<IndexRedirect />} />
          <Route path="/login" element={<LoginPage />} />
          <Route element={<ProtectedRoute />}>
            <Route path="/access-denied" element={<AccessDeniedPage />} />
            <Route element={<AdminRoute />}>
              <Route element={<AppLayout />}>
                <Route path="/dashboard" element={<DashboardPage />} />
                <Route path="/orders" element={<OrdersPage />} />
                <Route path="/orders/:publicId" element={<OrderDetailsPage />} />
                <Route path="/lockers" element={<ComingNextPage />} />
                <Route path="/devices" element={<ComingNextPage />} />
                <Route path="/notifications" element={<ComingNextPage />} />
                <Route path="/audit-log" element={<ComingNextPage />} />
              </Route>
            </Route>
          </Route>
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
