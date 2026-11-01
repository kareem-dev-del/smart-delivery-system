import { Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';
import { useLocale } from '../i18n/LocaleProvider';

export function NotFoundPage() {
  const { t } = useLocale();
  const { user, isAdmin } = useAuth();
  const destination = user ? (isAdmin ? '/dashboard' : '/access-denied') : '/login';
  return (
    <main className="not-found">
      <div>
        <div className="not-found-code">{t("ERROR / 404")}</div>
        <h1>{t("Page not found")}</h1>
        <p>{t("This address doesn’t map to a SmartDrop workspace page.")}</p>
        <Link to={destination} className="secondary-button" data-testid="link-return-home"><ArrowLeft size={14} />{t("Return to workspace")}</Link>
      </div>
    </main>
  );
}
