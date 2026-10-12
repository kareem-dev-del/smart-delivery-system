import { useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { Activity, Bell, Boxes, ClipboardList, FileClock, LayoutDashboard, LogOut, Menu, Monitor, ShieldCheck, X } from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';
import { Brand } from './Brand';

const navItems = [
  { label: 'Dashboard', to: '/dashboard', icon: LayoutDashboard, phase: false },
  { label: 'Orders', to: '/orders', icon: ClipboardList, phase: true },
  { label: 'Lockers', to: '/lockers', icon: Boxes, phase: true },
  { label: 'Devices', to: '/devices', icon: Monitor, phase: true },
  { label: 'Notifications', to: '/notifications', icon: Bell, phase: true },
  { label: 'Audit Log', to: '/audit-log', icon: FileClock, phase: true },
];

export function AppLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);
  const userName = user?.first_name ? `${user.first_name} ${user.last_name || ''}`.trim() : user?.username || 'Administrator';
  const initials = userName.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
  const currentLabel = navItems.find((item) => item.to === location.pathname)?.label || 'Operations';
  const handleLogout = () => {
    logout();
    navigate('/login', { replace: true });
  };

  return (
    <div className="app-frame">
      {menuOpen && <button className="mobile-scrim visible" aria-label="Close navigation" onClick={() => setMenuOpen(false)} data-testid="button-close-navigation" />}
      <aside className={`sidebar${menuOpen ? ' open' : ''}`} aria-label="Main navigation">
        <Brand />
        <div className="nav-section">Workspace</div>
        <nav className="nav-list">
          {navItems.map(({ label, to, icon: Icon, phase }) => (
            <NavLink key={to} to={to} className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`} onClick={() => setMenuOpen(false)} data-testid={`link-nav-${label.toLowerCase().replace(/\s+/g, '-')}`}>
              <Icon size={17} strokeWidth={1.8} /><span>{label}</span>{phase && <span className="nav-next">Next</span>}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-foot"><strong><Activity size={13} style={{ verticalAlign: '-2px', marginRight: 6 }} />Phase 1 foundation</strong>Operational modules are staged for the next phase.</div>
      </aside>
      <div className="main-column">
        <header className="topbar">
          <div className="topbar-left">
            <button className="icon-button menu-toggle" aria-label={menuOpen ? 'Close menu' : 'Open menu'} onClick={() => setMenuOpen(!menuOpen)} data-testid="button-toggle-navigation">
              {menuOpen ? <X size={17} /> : <Menu size={18} />}
            </button>
            <div className="topbar-kicker">Operations / {currentLabel}</div>
          </div>
          <div className="topbar-user">
            <div className="user-chip">
              <div className="avatar" aria-hidden="true">{initials}</div>
              <div><div className="user-name" data-testid="text-current-user">{userName}</div><div className="user-role">Administrator</div></div>
            </div>
            <button className="logout-button" onClick={handleLogout} data-testid="button-logout"><LogOut size={14} />Log out</button>
          </div>
        </header>
        <main className="page-content"><Outlet /></main>
      </div>
    </div>
  );
}

export function AdminBadge() {
  return <span className="phase-pill"><ShieldCheck size={13} /> Admin access</span>;
}
