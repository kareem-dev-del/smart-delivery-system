import { useNavigate } from 'react-router-dom';
import { ArrowLeft, LogOut, ShieldAlert } from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';
import { useLocale } from '../i18n/LocaleProvider';
import { LocaleToggle } from '../i18n/LocaleToggle';

export function AccessDeniedPage() {
  const { t } = useLocale();
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const handleLogout = () => {
    logout();
    navigate('/login', { replace: true });
  };
  return (
    <div className="app-frame">
      <main className="main-column">
        <header className="topbar"><div className="topbar-kicker">{t("SmartDrop / Access control")}</div><div className="topbar-user"><LocaleToggle /><button className="logout-button" onClick={handleLogout} data-testid="button-logout-denied"><LogOut size={14} />{t("Log out")}</button></div></header>
        <section className="denied-wrap">
          <div className="denied-symbol"><ShieldAlert size={23} /></div>
          <p className="eyebrow">{t("Restricted workspace")}</p>
          <h1 className="page-title">{t("Admin access required")}</h1>
          <p className="page-description" style={{ margin: '10px auto 0' }}>
            {user?.username ? (document.documentElement.lang === "ar" ? `الحساب “${user.username}” مسجل الدخول، لكنه لا يملك صلاحيات المدير.` : `The account “${user.username}” is signed in, but it does not have administrator permissions.`) : t("This account does not have administrator permissions.")}
            {' '}{t("Contact your SmartDrop administrator if you believe this is a mistake.")}
          </p>
          <div className="denied-actions">
            <button className="secondary-button" onClick={handleLogout} data-testid="button-sign-in-another-account"><ArrowLeft size={14} />{t("Sign in as another user")}</button>
            <button className="secondary-button" onClick={handleLogout} data-testid="button-logout-access-denied"><LogOut size={14} />{t("Log out")}</button>
          </div>
        </section>
      </main>
    </div>
  );
}
