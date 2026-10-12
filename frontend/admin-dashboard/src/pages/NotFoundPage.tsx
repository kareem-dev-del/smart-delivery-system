import { Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';

export function NotFoundPage() {
  const { user, isAdmin } = useAuth();
  const destination = user ? (isAdmin ? '/dashboard' : '/access-denied') : '/login';
  return (
    <main className="not-found">
      <div>
        <div className="not-found-code">ERROR / 404</div>
        <h1>Page not found</h1>
        <p>This address doesn’t map to a SmartDrop workspace page.</p>
        <Link to={destination} className="secondary-button" data-testid="link-return-home"><ArrowLeft size={14} />Return to workspace</Link>
      </div>
    </main>
  );
}
