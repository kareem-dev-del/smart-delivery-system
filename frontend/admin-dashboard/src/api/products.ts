import { apiGet, apiPatch, apiPost } from "./client";

export type ProductSize = "small" | "medium" | "large";

export interface AdminProduct {
  id: number;
  name: string;
  category: number | null;
  category_name: string | null;
  image: string | null;
  description: string;
  price: string;
  stock: number;
  size: ProductSize;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProductInput {
  name: string;
  category_id: number | null;
  image: File | null;
  clear_image: boolean;
  description: string;
  price: string;
  stock: number;
  size: ProductSize;
  is_active: boolean;
}

function productFormData(product: ProductInput): FormData {
  const data = new FormData();
  data.append("name", product.name);
  data.append("category_id", product.category_id === null ? "" : String(product.category_id));
  data.append("description", product.description);
  data.append("price", product.price);
  data.append("stock", String(product.stock));
  data.append("size", product.size);
  data.append("is_active", String(product.is_active));
  data.append("clear_image", String(product.clear_image));
  if (product.image) data.append("image", product.image);
  return data;
}

export interface AdminCategory {
  id: number;
  name: string;
  description: string;
  is_active: boolean;
  product_count: number;
  created_at: string;
  updated_at: string;
}

export interface CategoryInput {
  name: string;
  description: string;
  is_active: boolean;
}

export function getAdminCategories(accessToken: string): Promise<AdminCategory[]> {
  return apiGet<AdminCategory[]>("/api/products/admin/categories/", accessToken);
}

export function createCategory(
  accessToken: string,
  category: CategoryInput,
): Promise<AdminCategory> {
  return apiPost<AdminCategory>("/api/products/admin/categories/", accessToken, category);
}

export function updateCategory(
  accessToken: string,
  categoryId: number,
  category: Partial<CategoryInput>,
): Promise<AdminCategory> {
  return apiPatch<AdminCategory>(
    `/api/products/admin/categories/${categoryId}/`,
    accessToken,
    category,
  );
}

export function getAdminProducts(accessToken: string): Promise<AdminProduct[]> {
  return apiGet<AdminProduct[]>("/api/products/admin/", accessToken);
}

export function createProduct(
  accessToken: string,
  product: ProductInput,
): Promise<AdminProduct> {
  return apiPost<AdminProduct>("/api/products/", accessToken, productFormData(product));
}

export function updateProduct(
  accessToken: string,
  productId: number,
  product: ProductInput,
): Promise<AdminProduct> {
  return apiPatch<AdminProduct>(
    `/api/products/${productId}/`,
    accessToken,
    productFormData(product),
  );
}

export function setProductActive(
  accessToken: string,
  productId: number,
  isActive: boolean,
): Promise<AdminProduct> {
  return apiPatch<AdminProduct>(
    `/api/products/${productId}/`,
    accessToken,
    { is_active: isActive },
  );
}
