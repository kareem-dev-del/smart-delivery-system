import { useEffect, useMemo, useState, type FormEvent } from "react";
import {
  AlertTriangle,
  ArrowUpRight,
  Archive,
  Check,
  CirclePlus,
  FolderTree,
  ImagePlus,
  Package,
  Pencil,
  RefreshCw,
  Search,
  Upload,
  X,
} from "lucide-react";
import { Link } from "react-router-dom";

import {
  createProduct,
  getAdminCategories,
  getAdminProducts,
  setProductActive,
  updateProduct,
  type AdminProduct,
  type AdminCategory,
  type ProductInput,
  type ProductSize,
} from "../api/products";
import { useAuth } from "../auth/AuthProvider";
import { formatDate, formatLabel } from "../lib/format";
import { useLocale } from "../i18n/LocaleProvider";
import { StyledSelect } from "../components/StyledSelect";

type ProductFilter = "all" | "active" | "inactive" | "low-stock";
type CategoryFilter = number | "uncategorized" | null;

const EMPTY_FORM: ProductInput = {
  name: "",
  category_id: null,
  image: null,
  clear_image: false,
  description: "",
  price: "",
  stock: 0,
  size: "small",
  is_active: true,
};

function formatMoney(value: string): string {
  const amount = Number(value);
  return Number.isFinite(amount)
    ? new Intl.NumberFormat("en-EG", {
        style: "currency",
        currency: "EGP",
        maximumFractionDigits: 2,
      }).format(amount)
    : `${value} EGP`;
}

export function ProductsPage() {
  const { t, locale } = useLocale();
  const { tokens } = useAuth();
  const [products, setProducts] = useState<AdminProduct[]>([]);
  const [categories, setCategories] = useState<AdminCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [updatingProductId, setUpdatingProductId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<ProductFilter>("all");
  const [categoryFilter, setCategoryFilter] = useState<CategoryFilter>(null);
  const [editingProduct, setEditingProduct] = useState<AdminProduct | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState<ProductInput>(EMPTY_FORM);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageDragOver, setImageDragOver] = useState(false);

  useEffect(() => {
    if (!form.image) {
      setImagePreview(null);
      return;
    }
    const previewUrl = URL.createObjectURL(form.image);
    setImagePreview(previewUrl);
    return () => URL.revokeObjectURL(previewUrl);
  }, [form.image]);

  async function loadProducts() {
    if (!tokens?.access) {
      setError("Your session expired. Sign in again to manage products.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const [nextProducts, nextCategories] = await Promise.all([
        getAdminProducts(tokens.access),
        getAdminCategories(tokens.access),
      ]);
      setProducts(nextProducts);
      setCategories(nextCategories);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not load the product catalogue.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadProducts();
  }, [tokens?.access]);

  const totals = useMemo(
    () => ({
      all: products.length,
      active: products.filter((product) => product.is_active).length,
      lowStock: products.filter(
        (product) => product.is_active && product.stock <= 5,
      ).length,
      units: products.reduce((sum, product) => sum + product.stock, 0),
    }),
    [products],
  );

  const visibleProducts = useMemo(() => {
    const query = search.trim().toLowerCase();
    return products.filter((product) => {
      const matchesSearch =
        !query ||
        product.name.toLowerCase().includes(query) ||
        product.description.toLowerCase().includes(query);
      const matchesFilter =
        filter === "all" ||
        (filter === "active" && product.is_active) ||
        (filter === "inactive" && !product.is_active) ||
        (filter === "low-stock" && product.is_active && product.stock <= 5);
      const matchesCategory =
        categoryFilter === null ||
        (categoryFilter === "uncategorized" && product.category === null) ||
        product.category === categoryFilter;
      return matchesSearch && matchesFilter && matchesCategory;
    });
  }, [categoryFilter, filter, products, search]);

  const uncategorizedCount = products.filter((product) => product.category === null).length;

  function openCreateForm() {
    setEditingProduct(null);
    setForm(EMPTY_FORM);
    setFormOpen(true);
    setError(null);
    setNotice(null);
  }

  function openEditForm(product: AdminProduct) {
    setEditingProduct(product);
    setFormOpen(true);
    setForm({
      name: product.name,
      category_id: product.category,
      image: null,
      clear_image: false,
      description: product.description,
      price: product.price,
      stock: product.stock,
      size: product.size,
      is_active: product.is_active,
    });
    setError(null);
    setNotice(null);
  }

  function closeForm() {
    setEditingProduct(null);
    setForm(EMPTY_FORM);
    setFormOpen(false);
  }

  function selectProductImage(file?: File) {
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      setError("Product image must be 5 MB or smaller.");
      return;
    }
    setForm((current) => ({ ...current, image: file, clear_image: false }));
    setError(null);
  }

  async function toggleProductAvailability(product: AdminProduct) {
    if (!tokens?.access) {
      setError("Your session expired. Sign in again to manage products.");
      return;
    }

    const nextActive = !product.is_active;
    if (!nextActive && !window.confirm(
      `Deactivate ${product.name}? Customers will no longer be able to order it. Existing order history will remain unchanged.`,
    )) return;

    setUpdatingProductId(product.id);
    setError(null);
    setNotice(null);
    try {
      const updated = await setProductActive(tokens.access, product.id, nextActive);
      setProducts((current) => current.map((item) => item.id === updated.id ? updated : item));
      setNotice(locale === "ar" ? `${updated.name} ${updated.is_active ? "متاح الآن للعملاء." : "غير نشط الآن."}` : `${updated.name} is now ${updated.is_active ? "available" : "inactive"}.`);
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not update product availability.");
    } finally {
      setUpdatingProductId(null);
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access) {
      setError("Your session expired. Sign in again to save changes.");
      return;
    }

    if (form.image && form.image.size > 5 * 1024 * 1024) {
      setError("Product image must be 5 MB or smaller.");
      return;
    }

    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      const saved = editingProduct
        ? await updateProduct(tokens.access, editingProduct.id, form)
        : await createProduct(tokens.access, form);
      setProducts((current) =>
        editingProduct
          ? current.map((product) => (product.id === saved.id ? saved : product))
          : [...current, saved].sort((a, b) => a.name.localeCompare(b.name)),
      );
      setNotice(locale === "ar" ? (editingProduct ? "تم حفظ تغييرات المنتج." : "تم إنشاء المنتج.") : (editingProduct ? "Product changes saved." : "Product created."));
      closeForm();
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not save this product.",
      );
    } finally {
      setSaving(false);
    }
  }

  const editing = editingProduct !== null;

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">{t("Network control / Catalogue")}</p>
          <h1 className="page-title">{t("Products")}</h1>
          <p className="page-description">
            {t("Manage catalogue availability, inventory, and parcel size.")}
          </p>
        </div>
        <div className="products-page-actions">
          <button className="icon-text-button" type="button" onClick={() => void loadProducts()} disabled={loading}>
            <RefreshCw size={16} /> {t("Refresh")}
          </button>
          <button className="primary-action-button" type="button" onClick={openCreateForm}>
            <CirclePlus size={16} /> {t("Add product")}
          </button>
        </div>
      </div>

      {error && (
        <div className="scope-note error-note" role="alert">
          <AlertTriangle size={16} /><span>{error}</span>
        </div>
      )}
      {notice && (
        <div className="products-notice" role="status">
          <Check size={16} /><span>{t(notice)}</span>
        </div>
      )}

      <section className="products-metrics" aria-label={t("Catalogue summary")}>
        <article><span>{t("Products")}</span><strong>{totals.all}</strong></article>
        <article><span>{t("Active")}</span><strong>{totals.active}</strong></article>
        <article className={totals.lowStock ? "product-metric-warning" : ""}><span>{t("Low stock (5 or fewer)")}</span><strong>{totals.lowStock}</strong></article>
        <article><span>{t("Inventory units")}</span><strong>{totals.units}</strong></article>
      </section>

      <section className="product-category-shortcuts" aria-labelledby="product-category-heading">
        <div className="product-category-shortcuts-heading">
          <div>
            <h2 id="product-category-heading">{t("Browse by category")}</h2>
            <p>{t("Filter the catalogue by product category.")}</p>
          </div>
          <Link className="product-category-manage" to="/categories">
            {t("Manage categories")} <ArrowUpRight size={14} />
          </Link>
        </div>
        <div className="product-category-list">
          <button
            className={`product-category-tile${categoryFilter === null ? " is-selected" : ""}`}
            type="button"
            aria-pressed={categoryFilter === null}
            onClick={() => setCategoryFilter(null)}
          >
            <span className="product-category-icon"><Package size={16} /></span>
            <span className="product-category-copy"><strong>{t("All products")}</strong><small>{t("Every category")}</small></span>
            <span className="product-category-count">{products.length}</span>
          </button>
          {categories.map((category) => {
            const count = products.filter((product) => product.category === category.id).length;
            return (
              <button
                key={category.id}
                className={`product-category-tile${categoryFilter === category.id ? " is-selected" : ""}`}
                type="button"
                aria-pressed={categoryFilter === category.id}
                onClick={() => setCategoryFilter(category.id)}
              >
                <span className="product-category-icon"><FolderTree size={16} /></span>
                <span className="product-category-copy"><strong>{category.name}</strong><small>{t(category.is_active ? "Active category" : "Inactive category")}</small></span>
                <span className="product-category-count">{count}</span>
              </button>
            );
          })}
          {uncategorizedCount > 0 && (
            <button
              className={`product-category-tile${categoryFilter === "uncategorized" ? " is-selected" : ""}`}
              type="button"
              aria-pressed={categoryFilter === "uncategorized"}
              onClick={() => setCategoryFilter("uncategorized")}
            >
              <span className="product-category-icon"><Archive size={16} /></span>
              <span className="product-category-copy"><strong>{t("Uncategorized")}</strong><small>{t("Not assigned yet")}</small></span>
              <span className="product-category-count">{uncategorizedCount}</span>
            </button>
          )}
        </div>
      </section>

      {formOpen ? (
        <section className="product-form-panel" aria-labelledby="product-form-title">
          <div className="product-form-heading">
            <div>
              <p className="eyebrow">{t("Catalogue management")}</p>
              <h2 id="product-form-title">{t(editing ? "Edit product" : "New product")}</h2>
            </div>
            <button className="icon-button" type="button" aria-label={t("Close form")} onClick={closeForm}><X size={17} /></button>
          </div>
          <form className="product-form" onSubmit={handleSubmit}>
            <label className="product-form-field product-form-name">
              <span>{t("Product name")}</span>
              <input required maxLength={255} value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} />
            </label>
            <div className="product-image-field">
              <span className="product-image-label">{t("Product image")}</span>
              <div
                className={`product-image-dropzone${imageDragOver ? " is-dragging" : ""}`}
                onDragOver={(event) => {
                  event.preventDefault();
                  setImageDragOver(true);
                }}
                onDragLeave={(event) => {
                  if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
                    setImageDragOver(false);
                  }
                }}
                onDrop={(event) => {
                  event.preventDefault();
                  setImageDragOver(false);
                  selectProductImage(event.dataTransfer.files[0]);
                }}
              >
                <div className="product-image-preview">
                  {imagePreview || (editingProduct?.image && !form.clear_image) ? (
                    <img src={imagePreview || editingProduct?.image || ""} alt={t("Product preview")} />
                  ) : <Package size={25} aria-hidden="true" />}
                </div>
                <div className="product-image-inputs">
                  <strong>{form.image?.name || t(editingProduct?.image && !form.clear_image ? "Current product image" : "Add a product photo")}</strong>
                  <small>{form.image ? `${(form.image.size / (1024 * 1024)).toFixed(2)} MB` : t("JPG, PNG, or WebP | up to 5 MB")}</small>
                  <label className="product-image-choose">
                    {form.image || (editingProduct?.image && !form.clear_image) ? <ImagePlus size={15} /> : <Upload size={15} />}
                    {t(form.image || (editingProduct?.image && !form.clear_image) ? "Change image" : "Choose image")}
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      aria-label={t("Choose product image")}
                      onChange={(event) => {
                        selectProductImage(event.target.files?.[0]);
                        event.currentTarget.value = "";
                      }}
                    />
                  </label>
                </div>
                <span className="product-image-drop-hint">{t("or drag and drop here")}</span>
              </div>
              {editingProduct?.image && (
                <label className="product-image-remove">
                  <input
                    type="checkbox"
                    checked={form.clear_image}
                    onChange={(event) => setForm({
                      ...form,
                      clear_image: event.target.checked,
                      image: event.target.checked ? null : form.image,
                    })}
                  />
                  {t("Remove current image")}
                </label>
              )}
            </div>
            <label className="product-form-field">
              <span>{t("Price (EGP)")}</span>
              <input required type="number" min="0" step="0.01" value={form.price} onChange={(event) => setForm({ ...form, price: event.target.value })} />
            </label>
            <label className="product-form-field">
              <span>{t("Stock units")}</span>
              <input required type="number" min="0" step="1" value={form.stock} onChange={(event) => setForm({ ...form, stock: Number(event.target.value) })} />
            </label>
            <label className="product-form-field">
              <span>{t("Category")}</span>
              <StyledSelect
                ariaLabel={t("Category")}
                value={form.category_id === null ? "" : String(form.category_id)}
                onChange={(value) => setForm({ ...form, category_id: value ? Number(value) : null })}
                options={[
                  { value: "", label: t("Uncategorized") },
                  ...categories.filter((category) => category.is_active || category.id === form.category_id).map((category) => ({
                    value: String(category.id),
                    label: `${category.name}${category.is_active ? "" : ` (${t("Inactive")})`}`,
                  })),
                ]}
              />
            </label>
            <label className="product-form-field">
              <span>{t("Parcel size")}</span>
              <StyledSelect ariaLabel={t("Parcel size")} value={form.size} onChange={(value) => setForm({ ...form, size: value as ProductSize })} options={[
                { value: "small", label: t("Small") }, { value: "medium", label: t("Medium") }, { value: "large", label: t("Large") },
              ]} />
            </label>
            <label className="product-form-field product-form-description">
              <span>{t("Description")}</span>
              <textarea rows={3} value={form.description} onChange={(event) => setForm({ ...form, description: event.target.value })} />
            </label>
            <label className="product-active-toggle">
              <input type="checkbox" checked={form.is_active} onChange={(event) => setForm({ ...form, is_active: event.target.checked })} />
              <span><strong>{t("Available to customers")}</strong><small>{t("Inactive products remain visible to admins only.")}</small></span>
            </label>
            <div className="product-form-actions">
              <button className="icon-text-button" type="button" onClick={closeForm} disabled={saving}>{t("Cancel")}</button>
              <button className="primary-action-button" type="submit" disabled={saving}>
                {t(saving ? "Saving..." : editing ? "Save changes" : "Create product")}
              </button>
            </div>
          </form>
        </section>
      ) : null}

      <section className="products-catalogue-panel" aria-labelledby="catalogue-heading">
        <div className="products-panel-heading">
          <div>
            <h2 id="catalogue-heading">{t("Catalogue")}</h2>
            <p>{loading ? t("Loading products...") : locale === "ar" ? `${visibleProducts.length} من ${products.length} منتج` : `${visibleProducts.length} of ${products.length} products`}</p>
          </div>
          <div className="products-filters">
            <label className="products-search"><Search size={16} /><input aria-label={t("Search products")} placeholder={t("Search products")} value={search} onChange={(event) => setSearch(event.target.value)} /></label>
            <StyledSelect className="products-filter-select-trigger" ariaLabel={t("Filter products")} value={filter} onChange={(value) => setFilter(value as ProductFilter)} options={[
              { value: "all", label: t("All products") }, { value: "active", label: t("Active") },
              { value: "inactive", label: t("Inactive") }, { value: "low-stock", label: t("Low stock (5 or fewer)") },
            ]} />
          </div>
        </div>

        {loading ? (
          <div className="products-empty-state"><Package size={20} /><span>{t("Loading catalogue...")}</span></div>
        ) : visibleProducts.length === 0 ? (
          <div className="products-empty-state"><Archive size={20} /><span>{t(products.length ? "No products match this view." : "No products in the catalogue yet.")}</span></div>
        ) : (
          <div className="table-shell">
            <table className="data-table products-table">
              <thead><tr><th>{t("Product")}</th><th>{t("Category")}</th><th>{t("Price")}</th><th>{t("Stock")}</th><th>{t("Parcel size")}</th><th>{t("Availability")}</th><th>{t("Updated")}</th><th>{t("Action")}</th></tr></thead>
              <tbody>
                {visibleProducts.map((product) => (
                  <tr key={product.id}>
                    <td><div className="product-name-cell"><span className="product-row-icon">{product.image ? <img src={product.image} alt="" /> : <Package size={17} />}</span><span><strong>{product.name}</strong><small>{product.description || t("No description")}</small></span></div></td>
                    <td>{product.category_name || <span className="category-unassigned">{t("Uncategorized")}</span>}</td>
                    <td className="product-price-cell">{formatMoney(product.price)}</td>
                    <td><span className={product.stock <= 5 ? "product-stock-low" : "product-stock"}>{product.stock} {t("units")}</span></td>
                    <td>{t(formatLabel(product.size))}</td>
                    <td><span className={`product-state ${product.is_active ? "product-state-active" : "product-state-inactive"}`}>{t(product.is_active ? "Active" : "Inactive")}</span></td>
                    <td>{formatDate(product.updated_at)}</td>
                    <td>
                      <div className="product-row-actions">
                        <button className="product-edit-button" type="button" onClick={() => openEditForm(product)} aria-label={`${t("Edit")} ${product.name}`}><Pencil size={15} /> {t("Edit")}</button>
                        <button
                          className={`product-availability-action${product.is_active ? " deactivate" : " reactivate"}`}
                          type="button"
                          disabled={updatingProductId === product.id}
                          onClick={() => void toggleProductAvailability(product)}
                          aria-label={`${t(product.is_active ? "Deactivate" : "Reactivate")} ${product.name}`}
                        >
                          {product.is_active ? <Archive size={14} /> : <Check size={14} />}
                          {t(updatingProductId === product.id ? "Saving..." : product.is_active ? "Deactivate" : "Reactivate")}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}
