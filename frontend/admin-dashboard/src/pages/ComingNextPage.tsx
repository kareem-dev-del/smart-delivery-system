import { useLocation } from 'react-router-dom';
import { Bell, Boxes, ClipboardList, FileClock, Monitor, type LucideIcon } from 'lucide-react';
import { useLocale } from '../i18n/LocaleProvider';

const pageDetails: Record<string, { title: string; description: string; icon: LucideIcon }> = {
  '/orders': { title: 'Orders', description: 'Courier assignment, parcel tracking, and delivery handoff workflows will be available in a future phase.', icon: ClipboardList },
  '/lockers': { title: 'Lockers', description: 'Locker locations, drawer availability, and allocation controls are planned for a future phase.', icon: Boxes },
  '/devices': { title: 'Devices', description: 'Smart-locker device inventory, health, and configuration are planned for a future phase.', icon: Monitor },
  '/notifications': { title: 'Notifications', description: 'Network alerts and delivery communications will be introduced in a future phase.', icon: Bell },
  '/audit-log': { title: 'Audit log', description: 'A searchable record of administrative and operational activity is planned for a future phase.', icon: FileClock },
};

export function ComingNextPage() {
  const { t } = useLocale();
  const { pathname } = useLocation();
  const detail = pageDetails[pathname] || pageDetails['/orders'];
  const Icon = detail.icon;
  return (
    <>
      <p className="eyebrow">{t("Workspace / Planned module")}</p>
      <h1 className="page-title">{t(detail.title)}</h1>
      <p className="page-description">{t(detail.description)}</p>
      <section className="next-page-card" aria-label={`${t(detail.title)} ${t("next phase placeholder")}`}>
        <div className="next-page-icon"><Icon size={20} strokeWidth={1.8} /></div>
        <h2>{t("Coming in the next phase")}</h2>
        <p>{t("This area is intentionally not connected to operational data in Phase 1. Your workspace is ready for the feature rollout.")}</p>
        <span className="next-tag" style={{ marginTop: 15 }}>{t("Phase 1 · Foundation only")}</span>
      </section>
    </>
  );
}
