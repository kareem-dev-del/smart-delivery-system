import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { useNavigate } from "react-router-dom";
import {
  Activity, Boxes, ClipboardList, FolderTree, LayoutDashboard, Package,
  Search, UserRound, UsersRound, X,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

import { useAuth } from "../auth/AuthProvider";
import { getManagedAccounts } from "../api/accounts";
import { getLockerStations } from "../api/lockers";
import { getAdminOrders } from "../api/orders";
import { getAdminProducts } from "../api/products";
import { useLocale } from "../i18n/LocaleProvider";

interface SearchResult {
  id: string;
  title: string;
  detail: string;
  href: string;
  icon: LucideIcon;
}

const pages: Array<{ label: string; href: string; icon: LucideIcon; keywords: string }> = [
  { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard, keywords: "home overview" },
  { label: "Orders", href: "/orders", icon: ClipboardList, keywords: "delivery shipment" },
  { label: "Products", href: "/products", icon: Package, keywords: "catalogue inventory" },
  { label: "Categories", href: "/categories", icon: FolderTree, keywords: "catalogue" },
  { label: "People", href: "/people", icon: UsersRound, keywords: "users customers couriers admins" },
  { label: "My profile", href: "/profile", icon: UserRound, keywords: "account settings" },
  { label: "Lockers", href: "/lockers", icon: Boxes, keywords: "stations drawers" },
  { label: "Devices", href: "/devices", icon: Activity, keywords: "locker device" },
];

const normalize = (value: unknown) => String(value ?? "").toLocaleLowerCase().trim();

function loadSearchDirectories(accessToken: string) {
  return Promise.all([
    getAdminProducts(accessToken).catch(() => []),
    getManagedAccounts(accessToken).catch(() => []),
    getLockerStations(accessToken).catch(() => []),
  ]);
}

export function GlobalSearch() {
  const { t } = useLocale();
  const { tokens } = useAuth();
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const rootRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const directoryCache = useRef<{ accessToken: string; data: ReturnType<typeof loadSearchDirectories> } | null>(null);

  const pageResults = useMemo(() => {
    const needle = normalize(query);
    if (!needle) return [];
    return pages
      .filter((page) => normalize(`${page.label} ${t(page.label)} ${page.keywords}`).includes(needle))
      .map((page) => ({ id: page.href, title: t(page.label), detail: t("Open page"), href: page.href, icon: page.icon }));
  }, [query, t]);

  useEffect(() => {
    const needle = query.trim();
    if (!open || needle.length < 2 || !tokens?.access) {
      setResults(pageResults);
      setLoading(false);
      setActiveIndex(0);
      return;
    }

    let current = true;
    setLoading(true);
    const timer = window.setTimeout(async () => {
      if (!directoryCache.current || directoryCache.current.accessToken !== tokens.access) {
        directoryCache.current = { accessToken: tokens.access, data: loadSearchDirectories(tokens.access) };
      }
      const [ordersResult, directoriesResult] = await Promise.allSettled([
        getAdminOrders(tokens.access, { search: needle, pageSize: 5 }),
        directoryCache.current.data,
      ]);
      if (!current) return;

      const matches: SearchResult[] = [...pageResults];
      if (ordersResult.status === "fulfilled") {
        for (const order of ordersResult.value.results) {
          matches.push({
            id: `order-${order.public_id}`,
            title: `#${order.public_id.slice(0, 8)}`,
            detail: `${t("Order")} · ${order.customer_username} · ${order.items.map((item) => item.product_name).join(", ")}`,
            href: `/orders/${order.public_id}`,
            icon: ClipboardList,
          });
        }
      }
      if (directoriesResult.status === "fulfilled") {
        const [products, accounts, lockers] = directoriesResult.value;
        for (const product of products) {
          if (normalize(`${product.name} ${product.category_name} ${product.id}`).includes(normalize(needle))) {
            matches.push({ id: `product-${product.id}`, title: product.name, detail: t("Product"), href: "/products", icon: Package });
          }
        }
        for (const account of accounts) {
          const name = `${account.first_name} ${account.last_name}`.trim();
          if (normalize(`${name} ${account.username} ${account.email} ${account.phone} ${account.role}`).includes(normalize(needle))) {
            matches.push({ id: `account-${account.id}`, title: name || account.username, detail: `${t("Account")} · ${account.username}`, href: "/people", icon: UsersRound });
          }
        }
        for (const locker of lockers) {
          if (normalize(`${locker.name} ${locker.code} ${locker.address} ${locker.id}`).includes(normalize(needle))) {
            matches.push({ id: `locker-${locker.id}`, title: locker.name, detail: `${t("Locker station")} · ${locker.code}`, href: "/lockers", icon: Boxes });
          }
        }
      }

      setResults(matches.slice(0, 10));
      setLoading(false);
      setActiveIndex(0);
    }, 300);

    return () => {
      current = false;
      window.clearTimeout(timer);
    };
  }, [open, query, tokens?.access, pageResults, t]);

  useEffect(() => {
    const closeOnOutsideClick = (event: MouseEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", closeOnOutsideClick);
    return () => document.removeEventListener("mousedown", closeOnOutsideClick);
  }, []);

  const goToResult = (result: SearchResult) => {
    navigate(result.href);
    setQuery("");
    setOpen(false);
    inputRef.current?.blur();
  };

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Escape") { setOpen(false); inputRef.current?.blur(); }
    if (event.key === "ArrowDown" && results.length) { event.preventDefault(); setActiveIndex((index) => (index + 1) % results.length); }
    if (event.key === "ArrowUp" && results.length) { event.preventDefault(); setActiveIndex((index) => (index - 1 + results.length) % results.length); }
    if (event.key === "Enter" && results[activeIndex]) { event.preventDefault(); goToResult(results[activeIndex]); }
  };

  return (
    <div className="global-search" ref={rootRef}>
      <label className="global-search-field">
        <Search size={18} aria-hidden="true" />
        <input
          ref={inputRef}
          type="search"
          value={query}
          aria-label={t("Search operations")}
          aria-expanded={open}
          aria-controls="global-search-results"
          aria-autocomplete="list"
          placeholder={t("Search operations...")}
          onFocus={() => setOpen(true)}
          onChange={(event) => { setQuery(event.target.value); setOpen(true); }}
          onKeyDown={onKeyDown}
        />
        {query && <button className="global-search-clear" type="button" aria-label={t("Clear search")} onClick={() => { setQuery(""); inputRef.current?.focus(); }}><X size={15} /></button>}
      </label>
      {open && (query.trim().length > 0 || pageResults.length > 0) && (
        <div className="global-search-results" id="global-search-results" role="listbox" aria-label={t("Search results")}>
          {loading && <div className="global-search-message">{t("Searching...")}</div>}
          {!loading && results.length === 0 && <div className="global-search-message">{query.trim().length < 2 ? t("Type at least 2 characters") : t("No matching results")}</div>}
          {results.map((result, index) => {
            const Icon = result.icon;
            return <button key={result.id} className={`global-search-result${activeIndex === index ? " active" : ""}`} role="option" aria-selected={activeIndex === index} type="button" onMouseEnter={() => setActiveIndex(index)} onMouseDown={(event) => event.preventDefault()} onClick={() => goToResult(result)}>
              <span className="global-search-result-icon"><Icon size={17} /></span>
              <span className="global-search-result-copy"><strong>{result.title}</strong><small>{result.detail}</small></span>
            </button>;
          })}
          <div className="global-search-hint">{t("Use ↑ ↓ to navigate · Enter to open · Esc to close")}</div>
        </div>
      )}
    </div>
  );
}
