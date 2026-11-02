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
  updateCourierShift,
  updateManagedAccountStatus,
  type ManagedAccount,
  type ManagedAccountInput,
  type ManagedAccountRole,
} from "../api/accounts";
import { ApiRequestError } from "../api/client";
import { useAuth } from "../auth/AuthProvider";
import { formatDate, formatLabel } from "../lib/format";
import { useLocale } from "../i18n/LocaleProvider";
import { StyledSelect } from "../components/StyledSelect";

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
  const { t, locale } = useLocale();
  const { tokens, user } = useAuth();
  const [accounts, setAccounts] = useState<ManagedAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [updatingId, setUpdatingId] = useState<number | null>(null);
  const [updatingShiftId, setUpdatingShiftId] = useState<number | null>(null);
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
      setNotice(locale === "ar" ? `تم إنشاء حساب ${t(formatLabel(created.role))} للمستخدم ${created.username}.` : `${formatLabel(created.role)} account created for ${created.username}.`);
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
      setNotice(locale === "ar" ? `${updated.username} ${updated.is_active ? "نشط الآن." : "غير نشط الآن."}` : `${updated.username} is now ${updated.is_active ? "active" : "inactive"}.`);
    } catch (caughtError) {
      setError(getErrorMessage(caughtError));
    } finally {
      setUpdatingId(null);
    }
  }

  async function handleShiftChange(account: ManagedAccount) {
    if (!tokens?.access || account.role !== "courier") return;
    setUpdatingShiftId(account.id);
    setError(null);
    setNotice(null);
    try {
      const updated = await updateCourierShift(tokens.access, account.id, !account.is_on_shift);
      setAccounts((current) => current.map((item) => item.id === updated.id ? updated : item));
      setNotice(locale === "ar" ? `${updated.username} ${updated.is_on_shift ? "بدأ الوردية الآن" : "أنهى الوردية الآن"}.` : `${updated.username} is now ${updated.is_on_shift ? "on shift" : "off shift"}.`);
    } catch (caughtError) {
      setError(getErrorMessage(caughtError));
    } finally {
      setUpdatingShiftId(null);
    }
  }

  return (
    <div className="people-workspace">
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">{t("Network control / People")}</p>
          <h1 className="page-title">{t("People & access")}</h1>
          <p className="page-description">{t("Create customer, courier, and trusted admin accounts, and manage their access.")}</p>
        </div>
        <div className="products-page-actions">
          <button className="icon-text-button" type="button" onClick={() => void loadAccounts()} disabled={loading}>
            <RefreshCw size={15} /> {t("Refresh")}
          </button>
          <button className="primary-action-button" type="button" onClick={() => { setFormOpen((open) => !open); setError(null); setNotice(null); }}>
            <CirclePlus size={15} /> {t(formOpen ? "Close form" : "Add account")}
          </button>
        </div>
      </div>

      {error && <div className="scope-note error-note" role="alert"><AlertTriangle size={15} /><span>{error}</span></div>}
      {notice && <div className="products-notice" role="status"><Check size={15} /><span>{t(notice)}</span></div>}

      <section className="people-summary" aria-label={t("Account summary")}>
        <article><span>{t("Total accounts")}</span><strong>{summary.total}</strong></article>
        <article><span>{t("Customers")}</span><strong>{summary.customers}</strong></article>
        <article><span>{t("Couriers")}</span><strong>{summary.couriers}</strong></article>
        <article><span>{t("Admins")}</span><strong>{summary.admins}</strong></article>
        <article className={summary.inactive ? "people-summary-warning" : ""}><span>{t("Inactive")}</span><strong>{summary.inactive}</strong></article>
      </section>

      {formOpen && (
        <section className="people-form-panel" aria-labelledby="people-form-heading">
          <div className="product-form-heading">
            <div><p className="eyebrow">{t("Account administration")}</p><h2 id="people-form-heading">{t("Create account")}</h2></div>
          </div>
          <form className="people-form" onSubmit={handleCreate}>
            <label className="product-form-field"><span>{t("Account type")}</span><StyledSelect ariaLabel={t("Account type")} value={form.role} onChange={(value) => setForm({ ...form, role: value as ManagedAccountRole })} options={[{ value: "customer", label: t("Customer") }, { value: "courier", label: t("Courier") }, { value: "admin", label: t("Admin") }]} /></label>
            <label className="product-form-field"><span>{t("Username")}</span><input required minLength={3} maxLength={150} autoComplete="off" value={form.username} onChange={(event) => setForm({ ...form, username: event.target.value })} /></label>
            <label className="product-form-field"><span>{t("Phone")}</span><input required type="tel" maxLength={20} autoComplete="tel" placeholder="+2010..." value={form.phone} onChange={(event) => setForm({ ...form, phone: event.target.value })} /></label>
            <label className="product-form-field"><span>{t("First name")}</span><input maxLength={150} autoComplete="given-name" value={form.first_name} onChange={(event) => setForm({ ...form, first_name: event.target.value })} /></label>
            <label className="product-form-field"><span>{t("Last name")}</span><input maxLength={150} autoComplete="family-name" value={form.last_name} onChange={(event) => setForm({ ...form, last_name: event.target.value })} /></label>
            <label className="product-form-field"><span>{t("Email")}</span><input type="email" autoComplete="email" value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} /></label>
            <label className="product-form-field"><span>{t("Initial password")}</span><input required type="password" autoComplete="new-password" value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} /></label>
            <label className="product-form-field"><span>{t("Confirm password")}</span><input required type="password" autoComplete="new-password" value={form.password_confirm} onChange={(event) => setForm({ ...form, password_confirm: event.target.value })} /></label>
            <div className="people-form-foot"><span>{t("Admin accounts have full dashboard access. Create them only for trusted operators. Passwords are never returned after creation.")}</span><button className="primary-action-button" type="submit" disabled={saving}><UserRoundPlus size={15} />{t(saving ? "Creating..." : "Create account")}</button></div>
          </form>
        </section>
      )}

      <section className="people-directory-panel" aria-labelledby="people-directory-heading">
        <div className="people-directory-heading">
          <div><h2 id="people-directory-heading">{t("Account directory")}</h2><p>{loading ? t("Loading accounts...") : locale === "ar" ? `${visibleAccounts.length} من ${accounts.length} حساب` : `${visibleAccounts.length} of ${accounts.length} accounts`}</p></div>
          <label className="people-search"><Search size={15} /><input aria-label={t("Search accounts")} placeholder={t("Search name, username, email, phone")} value={search} onChange={(event) => setSearch(event.target.value)} /></label>
        </div>

        <div className="people-filters" role="group" aria-label={t("Filter accounts by role")}>
          {(["all", "customer", "courier", "admin"] as const).map((role) => (
            <button key={role} type="button" className={roleFilter === role ? "active" : ""} onClick={() => setRoleFilter(role)}>
              {t(role === "all" ? "All accounts" : role === "customer" ? "Customers" : role === "courier" ? "Couriers" : "Admins")}
            </button>
          ))}
        </div>

        {loading ? <div className="people-empty"><UsersRound size={19} />{t("Loading accounts...")}</div> : visibleAccounts.length === 0 ? (
          <div className="people-empty"><UserRound size={19} /><strong>{t("No accounts found")}</strong><span>{t("Try another search or create an account.")}</span></div>
        ) : (
          <div className="table-shell">
            <table className="data-table people-table">
              <thead><tr><th>{t("Account")}</th><th>{t("Role")}</th><th>{t("Phone")}</th><th>{t("Email")}</th><th>{t("Access")}</th><th>{t("Dispatch")}</th><th>{t("Actions")}</th></tr></thead>
              <tbody>{visibleAccounts.map((account) => (
                <tr key={account.id}>
                  <td><div className="people-name-cell"><span className={`people-avatar people-avatar-${account.role}`}>{account.role === "courier" ? <UserRoundPlus size={16} /> : account.role === "admin" ? <ShieldCheck size={16} /> : <UserRound size={16} />}</span><span><strong>{displayName(account)}</strong><small>@{account.username}</small></span></div></td>
                  <td><span className={`people-role people-role-${account.role}`}>{t(formatLabel(account.role))}</span></td>
                  <td>{account.phone || "-"}</td>
                  <td>{account.email || "-"}</td>
                  <td><span className={`people-status ${account.is_active ? "is-active" : "is-inactive"}`}><span />{t(account.is_active ? "Active" : "Inactive")}</span></td>
                  <td>{account.role === "courier" ? <span className={`people-dispatch-state dispatch-${account.dispatch_status}`}><span />{t(formatLabel(account.dispatch_status))}{account.active_order_count > 0 ? ` · ${account.active_order_count} ${t("active orders")}` : ""}</span> : "-"}</td>
                  <td><div className="people-actions-cell">{account.role === "courier" && <button className={`people-status-action ${account.is_on_shift ? "deactivate" : "activate"}`} type="button" title={account.active_order_count > 0 && account.is_on_shift ? t("Reassign active orders before ending this shift.") : undefined} disabled={!account.is_active || updatingShiftId === account.id || (account.is_on_shift && account.active_order_count > 0)} onClick={() => void handleShiftChange(account)}>{t(updatingShiftId === account.id ? "Saving..." : account.is_on_shift ? "End shift" : "Start shift")}</button>}{account.role === "admin" && account.username === user?.username ? <span className="people-current-account">{t("Current account")}</span> : <button className={`people-status-action ${account.is_active ? "deactivate" : "activate"}`} type="button" disabled={updatingId === account.id} onClick={() => void handleStatusChange(account)}>{t(updatingId === account.id ? "Saving..." : account.is_active ? "Deactivate" : "Reactivate")}</button>}</div></td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
      </section>
      <p className="people-retention-note">{t("Deactivated accounts cannot sign in. Their order history and audit records remain available.")}</p>
    </div>
  );
}
