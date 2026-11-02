import { useEffect, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { AlertCircle, ArrowRight, KeyRound, LoaderCircle } from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';
import { Brand } from '../components/Brand';
import { useLocale } from '../i18n/LocaleProvider';
import { LocaleToggle } from '../i18n/LocaleToggle';

export function LoginPage() {
  const { t } = useLocale();
  const { login, user, isAdmin, ready } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (ready && user) navigate(isAdmin ? '/dashboard' : '/access-denied', { replace: true });
  }, [ready, user, isAdmin, navigate]);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError('');
    setSubmitting(true);
    try {
      await login(username, password);
      navigate('/dashboard', { replace: true });
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Sign-in could not be completed. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="auth-screen">
      <LocaleToggle className="login-locale-switch" />
      <section className="auth-brand-panel">
        <Brand />
        <div className="auth-brand-copy">
          <p className="eyebrow">{t("Admin workspace")}</p>
          <h2 className="auth-headline">{t("Every handoff,")}<br />{t("accounted for.")}</h2>
          <p className="auth-description">{t("A clear view of the people, parcels, and smart lockers moving through your delivery network.")}</p>
        </div>
        <div className="auth-panel-foot">{t("Secure operations console / Phase 01")}</div>
      </section>
      <section className="auth-form-side">
        <div className="login-card">
          <h1>{t("Sign in")}</h1>
          <p className="login-lead">{t("Use your SmartDrop administrator credentials to continue.")}</p>
          {error && <div className="error-banner" role="alert" data-testid="status-login-error"><AlertCircle size={15} />{error}</div>}
          <form onSubmit={submit}>
            <div className="field">
              <label htmlFor="username">{t("Username")}</label>
              <input id="username" autoComplete="username" value={username} onChange={(event) => setUsername(event.target.value)} placeholder={t("Enter your username")} required disabled={submitting} data-testid="input-username" />
            </div>
            <div className="field">
              <label htmlFor="password">{t("Password")}</label>
              <input id="password" type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder={t("Enter your password")} required disabled={submitting} data-testid="input-password" />
            </div>
            <button className="primary-button" type="submit" disabled={submitting || !username || !password} data-testid="button-submit-login">
              {submitting ? <><LoaderCircle size={15} className="spin-icon" />{t("Connecting to SmartDrop…")}</> : <>{t("Continue")} <ArrowRight size={15} /></>}
            </button>
          </form>
          <div className="demo-helper">
            <div className="demo-heading"><KeyRound size={13} />{t("Demo credentials")}</div>
            <p className="demo-values">{t("Username")}&nbsp;&nbsp; demo-admin<br />{t("Password")}&nbsp;&nbsp; demo-password</p>
            <button type="button" className="demo-button" onClick={() => { setUsername('demo-admin'); setPassword('demo-password'); }} data-testid="button-fill-demo">{t("Fill sign-in fields")}</button>
          </div>
        </div>
      </section>
    </main>
  );
}
