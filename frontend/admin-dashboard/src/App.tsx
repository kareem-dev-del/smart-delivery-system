import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthProvider';
import { AppLayout } from './components/AppLayout';
import { AdminRoute, ProtectedRoute } from './components/ProtectedRoute';
import { AccessDeniedPage } from './pages/AccessDeniedPage';
import { DevicesPage } from './pages/DevicesPage';
import { DashboardPage } from './pages/DashboardPage';
import { LoginPage } from './pages/LoginPage';
import { NotFoundPage } from './pages/NotFoundPage';
import { OrdersPage } from './pages/OrdersPage';
import { OrderDetailsPage } from './pages/OrderDetailsPage';
import { LockersPage } from './pages/LockersPage';
import { NotificationsPage } from './pages/NotificationsPage';
import { AuditLogPage } from './pages/AuditLogPage';
import { ProductsPage } from './pages/ProductsPage';
import { PeoplePage } from './pages/PeoplePage';
import { CategoriesPage } from './pages/CategoriesPage';
import { ProfilePage } from './pages/ProfilePage';
import { LocaleProvider } from './i18n/LocaleProvider';

function IndexRedirect() {
  const { user, isAdmin, ready } = useAuth();
  if (!ready) return <div className="loading-page"><div><div className="loading-mark" /><span>Preparing workspace</span></div></div>;
  return <Navigate to={user ? (isAdmin ? '/dashboard' : '/access-denied') : '/login'} replace />;
}

function App() {
  return (
    <LocaleProvider>
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
                <Route path="/products" element={<ProductsPage />} />
                <Route path="/categories" element={<CategoriesPage />} />
                <Route path="/people" element={<PeoplePage />} />
                <Route path="/profile" element={<ProfilePage />} />
                <Route path="/orders/:publicId" element={<OrderDetailsPage />} />
                <Route path="/lockers" element={<LockersPage />} />
                <Route path="/devices" element={<DevicesPage />} />
                <Route path="/notifications" element={<NotificationsPage />} />
                <Route path="/audit-log" element={<AuditLogPage />} />
              </Route>
            </Route>
          </Route>
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
    </LocaleProvider>
  );
}

export default App;
