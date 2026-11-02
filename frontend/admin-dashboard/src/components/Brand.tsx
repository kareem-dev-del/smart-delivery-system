import { Boxes } from 'lucide-react';

import { useLocale } from "../i18n/LocaleProvider";

export function Brand() {
  const { t } = useLocale();
  return (
    <div className="brand" aria-label={t("SmartDrop Admin")}>
      <div className="brand-mark"><Boxes size={19} strokeWidth={2.1} /></div>
      <div>
        <div className="brand-name">SmartDrop</div>
        <div className="brand-caption">{t("Smart locker delivery operations")}</div>
      </div>
    </div>
  );
}
