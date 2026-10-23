import { useEffect, useMemo, useState, type FormEvent } from "react";
import {
  AlertTriangle,
  Check,
  CirclePlus,
  RefreshCw,
  Search,
  ShieldCheck,
  UserRound,
  UsersRound,
  UserRoundPlus,
} from "lucide-react";

import {
  createManagedAccount,
  getManagedAccounts,
  updateManagedAccountStatus,
  type ManagedAccount,
  type ManagedAccountInput,
  type ManagedAccountRole,
} from "../api/accounts";
import { ApiRequestError } from "../api/client";
import { useAuth } from "../auth/AuthProvider";
import { formatDate, formatLabel } from "../lib/format";

type RoleFilter = "all" | ManagedAccountRole;

const EMPTY_FORM: ManagedAccountInput = {
  username: "",
  password: "",
  password_confirm: "",
  first_name: "",
  last_name: "",
  email: "",
  phone: "",
  role: "customer",
};

function getErrorMessage(error: unknown): string {
  if (error instanceof ApiRequestError && error.details && typeof error.details === "object") {
    const messages = Object.entries(error.details as Record<string, unknown>).flatMap(([field, value]) => {
      const values = Array.isArray(value) ? value : [value];
      return values.map((item) => `${formatLabel(field)}: ${String(item)}`);
    });
    if (messages.length) return messages.join(" ");
  }
  return error instanceof Error ? error.message : "The account request could not be completed.";
}

function displayName(account: ManagedAccount): string {
  return `${account.first_name} ${account.last_name}`.trim() || account.username;
}

export function PeoplePage() {
  const { tokens, user } = useAuth();
  const [accounts, setAccounts] = useState<ManagedAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [updatingId, setUpdatingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<RoleFilter>("all");
  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState<ManagedAccountInput>(EMPTY_FORM);

  async function loadAccounts() {
    if (!tokens?.access) {
      setError("Your session expired. Sign in again to manage accounts.");
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      setAccounts(await getManagedAccounts(tokens.access));
    } catch (caughtError) {
      setError(getErrorMessage(caughtError));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadAccounts();
  }, [tokens?.access]);

  const summary = useMemo(() => ({
    total: accounts.length,
    customers: accounts.filter((account) => account.role === "customer").length,
    couriers: accounts.filter((account) => account.role === "courier").length,
    admins: accounts.filter((account) => account.role === "admin").length,
    inactive: accounts.filter((account) => !account.is_active).length,
  }), [accounts]);

  const visibleAccounts = useMemo(() => {
    const query = search.trim().toLowerCase();
    return accounts.filter((account) => {
      const matchesRole = roleFilter === "all" || account.role === roleFilter;
      const matchesSearch = !query || [
        account.username,
        account.first_name,
        account.last_name,
        account.email,
        account.phone,
      ].some((value) => value.toLowerCase().includes(query));
      return matchesRole && matchesSearch;
    });
  }, [accounts, roleFilter, search]);

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access) return;
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      const created = await createManagedAccount(tokens.access, form);
      setAccounts((current) => [...current, created].sort((a, b) => a.username.localeCompare(b.username)));
      setRoleFilter(created.role);
      setSearch("");
      setForm(EMPTY_FORM);
      setFormOpen(false);
      setNotice(`${formatLabel(created.role)} account created for ${created.username}.`);
    } catch (caughtError) {
      setError(getErrorMessage(caughtError));
    } finally {
      setSaving(false);
    }
  }

  async function handleStatusChange(account: ManagedAccount) {
    if (!tokens?.access) return;
    const nextActive = !account.is_active;
    if (!nextActive && !window.confirm(`Deactivate ${account.username}? They will lose access, while their order history is kept.`)) return;

    setUpdatingId(account.id);
    setError(null);
    setNotice(null);
    try {
      const updated = await updateManagedAccountStatus(tokens.access, account.id, nextActive);
      setAccounts((current) => current.map((item) => item.id === updated.id ? updated : item));
      setNotice(`${updated.username} is now ${updated.is_active ? "active" : "inactive"}.`);
    } catch (caughtError) {
      setError(getErrorMessage(caughtError));
    } finally {
      setUpdatingId(null);
    }
  }

  return (
    <div className="people-workspace">
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Network control / People</p>
          <h1 className="page-title">People &amp; access</h1>
          <p className="page-description">Create customer, courier, and trusted admin accounts, and manage their access.</p>
        </div>
        <div className="products-page-actions">
          <button className="icon-text-button" type="button" onClick={() => void loadAccounts()} disabled={loading}>
            <RefreshCw size={15} /> Refresh
          </button>
          <button className="primary-action-button" type="button" onClick={() => { setFormOpen((open) => !open); setError(null); setNotice(null); }}>
            <CirclePlus size={15} /> {formOpen ? "Close form" : "Add account"}
          </button>
        </div>
      </div>

      {error && <div className="scope-note error-note" role="alert"><AlertTriangle size={15} /><span>{error}</span></div>}
      {notice && <div className="products-notice" role="status"><Check size={15} /><span>{notice}</span></div>}

      <section className="people-summary" aria-label="Account summary">
        <article><span>Total accounts</span><strong>{summary.total}</strong></article>
        <article><span>Customers</span><strong>{summary.customers}</strong></article>
        <article><span>Couriers</span><strong>{summary.couriers}</strong></article>
        <article><span>Admins</span><strong>{summary.admins}</strong></article>
        <article className={summary.inactive ? "people-summary-warning" : ""}><span>Inactive</span><strong>{summary.inactive}</strong></article>
      </section>

      {formOpen && (
        <section className="people-form-panel" aria-labelledby="people-form-heading">
          <div className="product-form-heading">
            <div><p className="eyebrow">Account administration</p><h2 id="people-form-heading">Create account</h2></div>
          </div>
          <form className="people-form" onSubmit={handleCreate}>
            <label className="product-form-field"><span>Account type</span><select value={form.role} onChange={(event) => setForm({ ...form, role: event.target.value as ManagedAccountRole })}><option value="customer">Customer</option><option value="courier">Courier</option><option value="admin">Admin</option></select></label>
            <label className="product-form-field"><span>Username</span><input required minLength={3} maxLength={150} autoComplete="off" value={form.username} onChange={(event) => setForm({ ...form, username: event.target.value })} /></label>
            <label className="product-form-field"><span>Phone</span><input required type="tel" maxLength={20} autoComplete="tel" placeholder="+2010..." value={form.phone} onChange={(event) => setForm({ ...form, phone: event.target.value })} /></label>
            <label className="product-form-field"><span>First name</span><input maxLength={150} autoComplete="given-name" value={form.first_name} onChange={(event) => setForm({ ...form, first_name: event.target.value })} /></label>
            <label className="product-form-field"><span>Last name</span><input maxLength={150} autoComplete="family-name" value={form.last_name} onChange={(event) => setForm({ ...form, last_name: event.target.value })} /></label>
            <label className="product-form-field"><span>Email</span><input type="email" autoComplete="email" value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} /></label>
            <label className="product-form-field"><span>Initial password</span><input required type="password" autoComplete="new-password" value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} /></label>
            <label className="product-form-field"><span>Confirm password</span><input required type="password" autoComplete="new-password" value={form.password_confirm} onChange={(event) => setForm({ ...form, password_confirm: event.target.value })} /></label>
            <div className="people-form-foot"><span>Admin accounts have full dashboard access. Create them only for trusted operators. Passwords are never returned after creation.</span><button className="primary-action-button" type="submit" disabled={saving}><UserRoundPlus size={15} />{saving ? "Creating..." : "Create account"}</button></div>
          </form>
        </section>
      )}

      <section className="people-directory-panel" aria-labelledby="people-directory-heading">
        <div className="people-directory-heading">
          <div><h2 id="people-directory-heading">Account directory</h2><p>{loading ? "Loading accounts..." : `${visibleAccounts.length} of ${accounts.length} accounts`}</p></div>
          <label className="people-search"><Search size={15} /><input aria-label="Search accounts" placeholder="Search name, username, email, phone" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
        </div>

        <div className="people-filters" role="group" aria-label="Filter accounts by role">
          {(["all", "customer", "courier", "admin"] as const).map((role) => (
            <button key={role} type="button" className={roleFilter === role ? "active" : ""} onClick={() => setRoleFilter(role)}>
              {role === "all" ? "All accounts" : role === "customer" ? "Customers" : role === "courier" ? "Couriers" : "Admins"}
            </button>
          ))}
        </div>

        {loading ? <div className="people-empty"><UsersRound size={19} />Loading accounts...</div> : visibleAccounts.length === 0 ? (
          <div className="people-empty"><UserRound size={19} /><strong>No accounts found</strong><span>Try another search or create an account.</span></div>
        ) : (
          <div className="table-shell">
            <table className="data-table people-table">
              <thead><tr><th>Account</th><th>Role</th><th>Phone</th><th>Email</th><th>Status</th><th>Action</th></tr></thead>
              <tbody>{visibleAccounts.map((account) => (
                <tr key={account.id}>
                  <td><div className="people-name-cell"><span className={`people-avatar people-avatar-${account.role}`}>{account.role === "courier" ? <UserRoundPlus size={16} /> : account.role === "admin" ? <ShieldCheck size={16} /> : <UserRound size={16} />}</span><span><strong>{displayName(account)}</strong><small>@{account.username}</small></span></div></td>
                  <td><span className={`people-role people-role-${account.role}`}>{formatLabel(account.role)}</span></td>
                  <td>{account.phone || "-"}</td>
                  <td>{account.email || "-"}</td>
                  <td><span className={`people-status ${account.is_active ? "is-active" : "is-inactive"}`}><span />{account.is_active ? "Active" : "Inactive"}</span></td>
                  <td>{account.role === "admin" && account.username === user?.username ? <span className="people-current-account">Current account</span> : <button className={`people-status-action ${account.is_active ? "deactivate" : "activate"}`} type="button" disabled={updatingId === account.id} onClick={() => void handleStatusChange(account)}>{updatingId === account.id ? "Saving..." : account.is_active ? "Deactivate" : "Reactivate"}</button>}</td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
      </section>
      <p className="people-retention-note">Deactivated accounts cannot sign in. Their order history and audit records remain available.</p>
    </div>
  );
}
