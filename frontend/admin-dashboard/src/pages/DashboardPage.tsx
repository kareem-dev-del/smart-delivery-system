import { Activity, Bell, Boxes, ClipboardList, Info, Monitor } from 'lucide-react';
import { AdminBadge } from '../components/AppLayout';

const modules = [
  { title: 'Orders', copy: 'Courier assignment and parcel handoff workflows.', icon: ClipboardList },
  { title: 'Lockers', copy: 'Drawer allocation and locker location operations.', icon: Boxes },
  { title: 'Devices', copy: 'Smart-locker health and device administration.', icon: Monitor },
  { title: 'Notifications', copy: 'Operational alerts and delivery communications.', icon: Bell },
];

export function DashboardPage() {
  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Network control / Phase 1</p>
          <h1 className="page-title">Operations Dashboard</h1>
          <p className="page-description">The admin workspace foundation is ready. Operational data and workflows will be introduced in the next phase.</p>
        </div>
        <AdminBadge />
      </div>
      <section aria-labelledby="modules-heading">
        <h2 id="modules-heading" className="section-heading">Operations modules</h2>
        <p className="section-subtitle">Planned capabilities for the SmartDrop network.</p>
        <div className="module-grid">
          {modules.map(({ title, copy, icon: Icon }) => (
            <article className="module-card" key={title} data-testid={`card-module-${title.toLowerCase()}`}>
              <div className="module-card-top"><div className="module-icon"><Icon size={17} strokeWidth={1.8} /></div><span className="next-tag">Next phase</span></div>
              <h3 className="module-title">{title}</h3>
              <p className="module-copy">{copy}</p>
            </article>
          ))}
        </div>
      </section>
      <div className="scope-note"><Info size={15} /><span><strong>Phase 1 foundation.</strong> Live orders, locker inventory, device status, and alert data are not connected yet. No operational metrics are shown in this release.</span></div>
    </>
  );
}
