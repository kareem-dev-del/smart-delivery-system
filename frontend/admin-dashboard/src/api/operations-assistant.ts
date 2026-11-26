import { apiPost } from "./client";

export interface OperationsEvidence {
  tool: string;
  data: Record<string, unknown>;
}

export interface OperationsAssistantResponse {
  answer: string;
  evidence: OperationsEvidence[];
  model: string;
}

export function askOperationsAssistant(accessToken: string, question: string) {
  return apiPost<OperationsAssistantResponse>(
    "/api/lockers/admin/operations-assistant/",
    accessToken,
    { question },
  );
}
