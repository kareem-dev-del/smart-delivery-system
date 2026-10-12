import { useEffect, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { AlertCircle, ArrowRight, KeyRound, LoaderCircle } from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';
import { Brand } from '../components/Brand';

export function LoginPage() {
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
      <section className="auth-brand-panel">
        <Brand />
        <div className="auth-brand-copy">
          <p className="eyebrow">Admin workspace</p>
          <h2 className="auth-headline">Every handoff,<br />accounted for.</h2>
          <p className="auth-description">A clear view of the people, parcels, and smart lockers moving through your delivery network.</p>
        </div>
        <div className="auth-panel-foot">Secure operations console&nbsp; / &nbsp;Phase 01</div>
      </section>
      <section className="auth-form-side">
        <div className="login-card">
          <h1>Sign in</h1>
          <p className="login-lead">Use your SmartDrop administrator credentials to continue.</p>
          {error && <div className="error-banner" role="alert" data-testid="status-login-error"><AlertCircle size={15} />{error}</div>}
          <form onSubmit={submit}>
            <div className="field">
              <label htmlFor="username">Username</label>
              <input id="username" autoComplete="username" value={username} onChange={(event) => setUsername(event.target.value)} placeholder="Enter your username" required disabled={submitting} data-testid="input-username" />
            </div>
            <div className="field">
              <label htmlFor="password">Password</label>
              <input id="password" type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Enter your password" required disabled={submitting} data-testid="input-password" />
            </div>
            <button className="primary-button" type="submit" disabled={submitting || !username || !password} data-testid="button-submit-login">
              {submitting ? <><LoaderCircle size={15} className="spin-icon" />Connecting to SmartDrop…</> : <>Continue <ArrowRight size={15} /></>}
            </button>
          </form>
          <div className="demo-helper">
            <div className="demo-heading"><KeyRound size={13} />Demo credentials</div>
            <p className="demo-values">Username&nbsp;&nbsp; demo-admin<br />Password&nbsp;&nbsp; demo-password</p>
            <button type="button" className="demo-button" onClick={() => { setUsername('demo-admin'); setPassword('demo-password'); }} data-testid="button-fill-demo">Fill sign-in fields</button>
          </div>
        </div>
      </section>
    </main>
  );
}
