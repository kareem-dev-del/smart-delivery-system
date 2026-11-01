import { useEffect, useMemo, useState, type FormEvent } from "react";
import {
  AlertTriangle,
  Check,
  CirclePlus,
  FolderTree,
  Pencil,
  RefreshCw,
  X,
} from "lucide-react";

import {
  createCategory,
  getAdminCategories,
  updateCategory,
  type AdminCategory,
  type CategoryInput,
} from "../api/products";
import { useAuth } from "../auth/AuthProvider";
import { formatDate } from "../lib/format";
import { useLocale } from "../i18n/LocaleProvider";

const EMPTY_FORM: CategoryInput = {
  name: "",
  description: "",
  is_active: true,
};

export function CategoriesPage() {
  const { t, locale } = useLocale();
  const { tokens } = useAuth();
  const [categories, setCategories] = useState<AdminCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [editing, setEditing] = useState<AdminCategory | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState<CategoryInput>(EMPTY_FORM);

  async function loadCategories() {
    if (!tokens?.access) {
      setError("Your session expired. Sign in again to manage categories.");
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      setCategories(await getAdminCategories(tokens.access));
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not load categories.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadCategories();
  }, [tokens?.access]);

  const counts = useMemo(() => ({
    total: categories.length,
    active: categories.filter((category) => category.is_active).length,
    assigned: categories.reduce((count, category) => count + (category.product_count ?? 0), 0),
  }), [categories]);

  function openCreate() {
    setEditing(null);
    setForm(EMPTY_FORM);
    setError(null);
    setNotice(null);
    setFormOpen(true);
  }

  function openEdit(category: AdminCategory) {
    setEditing(category);
    setForm({ name: category.name, description: category.description, is_active: category.is_active });
    setError(null);
    setNotice(null);
    setFormOpen(true);
  }

  function closeForm() {
    setEditing(null);
    setForm(EMPTY_FORM);
    setFormOpen(false);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access) {
      setError("Your session expired. Sign in again to save changes.");
      return;
    }
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      const saved = editing
        ? await updateCategory(tokens.access, editing.id, form)
        : await createCategory(tokens.access, form);
      setCategories((current) => editing
        ? current.map((category) => category.id === saved.id ? saved : category)
        : [...current, saved].sort((a, b) => a.name.localeCompare(b.name)));
      setNotice(locale === "ar" ? (editing ? "تم حفظ تعديلات الفئة." : "تم إنشاء الفئة.") : (editing ? "Category changes saved." : "Category created."));
      closeForm();
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not save this category.");
    } finally {
      setSaving(false);
    }
  }

  async function toggleCategory(category: AdminCategory) {
    if (!tokens?.access) {
      setError("Your session expired. Sign in again to change category availability.");
      return;
    }
    setError(null);
    setNotice(null);
    try {
      const saved = await updateCategory(tokens.access, category.id, { is_active: !category.is_active });
      setCategories((current) => current.map((item) => item.id === saved.id ? saved : item));
      setNotice(locale === "ar" ? (saved.is_active ? `${saved.name} متاحة للعملاء.` : `${saved.name} تم تعطيلها.`) : (saved.is_active ? `${saved.name} is available to customers.` : `${saved.name} was deactivated.`));
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not update category availability.");
    }
  }

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">{t("Network control / Catalogue")}</p>
          <h1 className="page-title">{t("Categories")}</h1>
          <p className="page-description">{t("Organize products and control which categories customers can browse.")}</p>
        </div>
        <div className="products-page-actions">
          <button className="icon-text-button" type="button" onClick={() => void loadCategories()} disabled={loading}>
            <RefreshCw size={16} /> {t("Refresh")}
          </button>
          <button className="primary-action-button" type="button" onClick={openCreate}>
            <CirclePlus size={16} /> {t("Add category")}
          </button>
        </div>
      </div>

      {error && <div className="scope-note error-note" role="alert"><AlertTriangle size={16} /><span>{error}</span></div>}
      {notice && <div className="products-notice" role="status"><Check size={16} /><span>{t(notice)}</span></div>}

      <section className="products-metrics categories-metrics" aria-label={t("Category summary")}>
        <article><span>{t("Total categories")}</span><strong>{counts.total}</strong></article>
        <article><span>{t("Active categories")}</span><strong>{counts.active}</strong></article>
        <article><span>{t("Products assigned")}</span><strong>{counts.assigned}</strong></article>
      </section>

      {formOpen && (
        <section className="product-form-panel" aria-labelledby="category-form-title">
          <div className="product-form-heading">
            <div><p className="eyebrow">{t("Catalogue management")}</p><h2 id="category-form-title">{t(editing ? "Edit category" : "New category")}</h2></div>
            <button className="icon-button" type="button" aria-label={t("Close form")} onClick={closeForm}><X size={17} /></button>
          </div>
          <form className="category-form" onSubmit={handleSubmit}>
            <label className="product-form-field">
              <span>{t("Category name")}</span>
              <input required maxLength={100} value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} />
            </label>
            <label className="product-form-field">
              <span>{t("Description")}</span>
              <textarea rows={3} value={form.description} onChange={(event) => setForm({ ...form, description: event.target.value })} />
            </label>
            <label className="product-active-toggle">
              <input type="checkbox" checked={form.is_active} onChange={(event) => setForm({ ...form, is_active: event.target.checked })} />
              <span><strong>{t("Available to customers")}</strong><small>{t("Products keep their category if it is deactivated.")}</small></span>
            </label>
            <div className="product-form-actions">
              <button className="icon-text-button" type="button" onClick={closeForm} disabled={saving}>{t("Cancel")}</button>
              <button className="primary-action-button" type="submit" disabled={saving}>{t(saving ? "Saving..." : editing ? "Save changes" : "Create category")}</button>
            </div>
          </form>
        </section>
      )}

      <section className="products-catalogue-panel" aria-labelledby="categories-heading">
        <div className="products-panel-heading">
          <div><h2 id="categories-heading">{t("Category list")}</h2><p>{loading ? t("Loading categories...") : locale === "ar" ? `${categories.length} فئة` : `${categories.length} categories`}</p></div>
        </div>
        {loading ? (
          <div className="products-empty-state"><FolderTree size={20} /><span>{t("Loading categories...")}</span></div>
        ) : categories.length === 0 && error ? (
          <div className="products-empty-state"><AlertTriangle size={20} /><span>{t("Categories could not be loaded. Refresh after the API is available.")}</span></div>
        ) : categories.length === 0 ? (
          <div className="products-empty-state"><FolderTree size={20} /><span>{t("No categories yet. Create one to organize your products.")}</span></div>
        ) : (
          <div className="table-shell">
            <table className="data-table categories-table">
              <thead><tr><th>{t("Category")}</th><th>{t("Description")}</th><th>{t("Products")}</th><th>{t("Availability")}</th><th>{t("Updated")}</th><th>{t("Actions")}</th></tr></thead>
              <tbody>{categories.map((category) => (
                <tr key={category.id}>
                  <td><div className="category-name-cell"><span className="product-row-icon"><FolderTree size={17} /></span><strong>{category.name}</strong></div></td>
                  <td>{category.description || <span className="category-unassigned">{t("No description")}</span>}</td>
                  <td>{category.product_count ?? "—"}</td>
                  <td><span className={`product-state ${category.is_active ? "product-state-active" : "product-state-inactive"}`}>{t(category.is_active ? "Active" : "Inactive")}</span></td>
                  <td>{formatDate(category.updated_at)}</td>
                  <td><div className="category-row-actions">
                    <button className="product-edit-button" type="button" onClick={() => openEdit(category)} aria-label={`${t("Edit")} ${category.name}`}><Pencil size={14} /> {t("Edit")}</button>
                    <button className="category-toggle-button" type="button" onClick={() => void toggleCategory(category)}>{t(category.is_active ? "Deactivate" : "Activate")}</button>
                  </div></td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}
