import { useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import {
  Activity,
  Bell,
  Boxes,
  ClipboardList,
  FileClock,
  LayoutDashboard,
  LogOut,
  Menu,
  Monitor,
  Search,
  ShieldCheck,
  X,
} from "lucide-react";

import { useAuth } from "../auth/AuthProvider";
import { Brand } from "./Brand";

const navItems = [
  { label: "Dashboard", to: "/dashboard", icon: LayoutDashboard, badge: null },
  { label: "Orders", to: "/orders", icon: ClipboardList, badge: null },
  { label: "Lockers", to: "/lockers", icon: Boxes, badge: null },
  { label: "Devices", to: "/devices", icon: Monitor, badge: null },
  { label: "Notifications", to: "/notifications", icon: Bell, badge: null },
  { label: "Audit Log", to: "/audit-log", icon: FileClock, badge: null },
];

export function AppLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  const userName = user?.first_name
    ? `${user.first_name} ${user.last_name || ""}`.trim()
    : user?.username || "Administrator";

  const initials = userName
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();

  const currentLabel =
    navItems.find((item) => item.to === location.pathname)?.label ||
    "Operations";

  const handleLogout = () => {
    logout();
    navigate("/login", { replace: true });
  };

  return (
    <div className="app-frame">
      {menuOpen && (
        <button
          className="mobile-scrim visible"
          aria-label="Close navigation"
          onClick={() => setMenuOpen(false)}
          data-testid="button-close-navigation"
        />
      )}

      <aside
        className={`sidebar${menuOpen ? " open" : ""}`}
        aria-label="Main navigation"
      >
        <div className="sidebar-brand-block">
          <Brand />
        </div>

        <div className="nav-section">Operations</div>

        <nav className="nav-list">
          {navItems.map(({ label, to, icon: Icon, badge }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) => `nav-link${isActive ? " active" : ""}`}
              onClick={() => setMenuOpen(false)}
              data-testid={`link-nav-${label.toLowerCase().replace(/\s+/g, "-")}`}
            >
              <span className="nav-link-main">
                <Icon size={17} strokeWidth={1.9} />
                <span>{label}</span>
              </span>
              {badge && <span className="nav-next">{badge}</span>}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-foot">
          <strong>
            <Activity size={13} />
            Live workspace
          </strong>
          <span>Admin tools connected to SmartDrop backend APIs.</span>
        </div>
      </aside>

      <div className="main-column">
        <header className="topbar">
          <div className="topbar-left">
            <button
              className="icon-button menu-toggle"
              aria-label={menuOpen ? "Close menu" : "Open menu"}
              onClick={() => setMenuOpen(!menuOpen)}
              data-testid="button-toggle-navigation"
            >
              {menuOpen ? <X size={17} /> : <Menu size={18} />}
            </button>

            <div>
              <div className="topbar-kicker">SmartDrop Admin</div>
              <div className="topbar-title">{currentLabel}</div>
            </div>
          </div>

          <div className="topbar-search" aria-label="Search placeholder">
            <Search size={16} />
            <span>Search operations...</span>
          </div>

          <div className="topbar-user">
            <div className="user-chip">
              <div className="avatar" aria-hidden="true">
                {initials}
              </div>
              <div>
                <div className="user-name" data-testid="text-current-user">
                  {userName}
                </div>
                <div className="user-role">Administrator</div>
              </div>
            </div>

            <button
              className="logout-button"
              onClick={handleLogout}
              data-testid="button-logout"
            >
              <LogOut size={14} />
              Log out
            </button>
          </div>
        </header>

        <main className="page-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

export function AdminBadge() {
  return (
    <span className="phase-pill">
      <ShieldCheck size={13} />
      Admin access
    </span>
  );
}