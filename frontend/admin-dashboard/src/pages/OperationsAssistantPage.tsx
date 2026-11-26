import { useState, type FormEvent } from "react";
import { Bot, Database, LoaderCircle, Send, Sparkles } from "lucide-react";

import {
  askOperationsAssistant,
  type OperationsAssistantResponse,
} from "../api/operations-assistant";
import { useAuth } from "../auth/AuthProvider";
import { useLocale } from "../i18n/LocaleProvider";
import { ApiRequestError } from "../api/client";

const suggestions = [
  "Summarize today's order workload and the main operational risks.",
  "Which lockers have the least available drawer capacity?",
  "How many orders have been waiting over two hours, and what should we inspect?",
];

function errorMessage(error: unknown): string {
  if (error instanceof ApiRequestError) {
    if (error.details && typeof error.details === "object") {
      const detail = (error.details as Record<string, unknown>).detail;
      if (typeof detail === "string") return detail;
    }
  }
  return error instanceof Error ? error.message : "The assistant could not answer right now.";
}

function EvidenceCard({ evidence }: { evidence: OperationsAssistantResponse["evidence"][number] }) {
  const { t } = useLocale();
  return (
    <article className="assistant-evidence-card">
      <h3><Database size={15} /> {t(evidence.tool)}</h3>
      <dl>
        {Object.entries(evidence.data).map(([key, value]) => (
          <div key={key}>
            <dt>{t(key.replaceAll("_", " "))}</dt>
            <dd>{typeof value === "object" && value !== null ? JSON.stringify(value) : String(value ?? "—")}</dd>
          </div>
        ))}
      </dl>
    </article>
  );
}

export function OperationsAssistantPage() {
  const { t } = useLocale();
  const { tokens } = useAuth();
  const [question, setQuestion] = useState("");
  const [response, setResponse] = useState<OperationsAssistantResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submitQuestion(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access || !question.trim()) return;
    setLoading(true);
    setError(null);
    setResponse(null);
    try {
      setResponse(await askOperationsAssistant(tokens.access, question.trim()));
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">{t("Competition demo / AI operations")}</p>
          <h1 className="page-title">{t("Operations assistant")}</h1>
          <p className="page-description">{t("Ask operational questions. Gemini selects read-only tools that query current SmartDrop data, then explains the evidence it used.")}</p>
        </div>
      </div>

      <div className="assistant-privacy-note" role="note">
        <Sparkles size={17} />
        <span><strong>{t("Privacy note")}</strong> — {t("Do not include names, phone numbers, addresses, or other personal details. Your question and anonymized operational facts may be sent to Gemini. The free tier may use submitted content to improve Google's products.")}</span>
      </div>

      <section className="orders-table-panel assistant-panel">
        <div className="assistant-heading">
          <span className="assistant-avatar"><Bot size={21} /></span>
          <div><h2 className="section-heading">{t("SmartDrop operations")}</h2><p className="section-subtitle">{t("Read-only assistant · live data · no operational changes")}</p></div>
        </div>

        <div className="assistant-suggestions" aria-label={t("Suggested questions")}>
          {suggestions.map((suggestion) => (
            <button key={suggestion} type="button" onClick={() => setQuestion(suggestion)} disabled={loading}>{t(suggestion)}</button>
          ))}
        </div>

        <form className="assistant-question-form" onSubmit={submitQuestion}>
          <label htmlFor="operations-question">{t("Ask about orders, lockers, or a specific order UUID")}</label>
          <textarea id="operations-question" value={question} onChange={(event) => setQuestion(event.target.value)} maxLength={500} rows={3} placeholder={t("For example: which stations have no available drawers?")} />
          <div className="assistant-submit-row">
            <span>{question.length}/500</span>
            <button className="primary-button" type="submit" disabled={loading || question.trim().length < 5}>
              {loading ? <LoaderCircle className="assistant-spinner" size={16} /> : <Send size={16} />}
              {loading ? t("Checking live data...") : t("Ask assistant")}
            </button>
          </div>
        </form>

        {error && <div className="scope-note error-note" role="alert">{error}</div>}
        {response && (
          <section className="assistant-answer" aria-live="polite">
            <div className="assistant-answer-title"><Sparkles size={17} /><h2>{t("Assistant answer")}</h2></div>
            <p>{response.answer}</p>
            <div className="assistant-evidence-heading"><Database size={15} /><h3>{t("Live evidence used")}</h3><span>{response.model}</span></div>
            <div className="assistant-evidence-grid">
              {response.evidence.map((item, index) => <EvidenceCard key={`${item.tool}-${index}`} evidence={item} />)}
            </div>
          </section>
        )}
      </section>
    </>
  );
}
