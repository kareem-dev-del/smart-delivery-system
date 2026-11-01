import { Languages } from "lucide-react";
import { useLocale } from "./LocaleProvider";

export function LocaleToggle({ className = "locale-switch" }: { className?: string }) {
  const { locale, setLocale } = useLocale();
  const nextLocale = locale === "ar" ? "en" : "ar";
  return (
    <button
      className={className}
      type="button"
      onClick={() => setLocale(nextLocale)}
      aria-label={locale === "ar" ? "Switch language to English" : "تغيير اللغة إلى العربية"}
      title={locale === "ar" ? "Switch to English" : "التغيير إلى العربية"}
    >
      <Languages size={15} aria-hidden="true" />
      <span>{locale === "ar" ? "English" : "العربية"}</span>
    </button>
  );
}
