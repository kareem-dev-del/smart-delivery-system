import { useEffect, useRef } from "react";

/** Refresh visible page data without reloading the document. */
export function useAutoRefresh(
  refresh: () => Promise<void>,
  intervalMs = 15_000,
  enabled = true,
) {
  const refreshRef = useRef(refresh);
  const inFlightRef = useRef(false);

  useEffect(() => {
    refreshRef.current = refresh;
  }, [refresh]);

  useEffect(() => {
    if (!enabled) return;

    const timer = window.setInterval(() => {
      if (document.visibilityState !== "visible" || inFlightRef.current) return;

      inFlightRef.current = true;
      void refreshRef.current().finally(() => {
        inFlightRef.current = false;
      });
    }, intervalMs);

    return () => window.clearInterval(timer);
  }, [enabled, intervalMs]);
}
