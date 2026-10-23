/**
 * Lovable AI Gateway — server-only call path.
 *
 * Every chat/text call in Roshan goes through here. The key, the prompts and
 * the model id never reach the browser: this file is only imported from
 * inside server-function handlers, so it stays out of the client bundle.
 *
 * Contract:
 * - `openai/gpt-6-astra` served on `/v1/responses` (verified available for
 *   this workspace; `data_retention` is `zero` on that surface).
 * - Every call streams and is consumed server-side; nothing is buffered with
 *   a non-streaming call.
 * - `store: false` — the gateway is stateless, so history is always resent
 *   inline by the caller instead of as item references.
 * - Reasoning stays on (required by this model) at `low` effort.
 * - No `temperature` / `top_p` (this model rejects them).
 */

import { createOpenAI } from "@ai-sdk/openai";
import { streamText, type ModelMessage } from "ai";

import { redactSensitive } from "@/lib/redact";

import { createLovableAiGatewayRunIdFetch } from "./run-id.ts";

const GATEWAY_BASE_URL = "https://ai.gateway.lovable.dev/v1";

/** Resolved default chat model for this workspace. Never invented from memory. */
export const AI_MODEL_ID = "openai/gpt-6-astra";

/** Reasoning and visible output share one budget, so this is deliberately generous. */
const DEFAULT_MAX_OUTPUT_TOKENS = 4000;

export type AiTextCall = {
  /** System prompt: role, safety rules and the exact output shape. */
  instructions: string;
  /** The record data and the request, built server-side. */
  prompt: string;
  maxOutputTokens?: number;
};

function requireLovableApiKey(): string {
  const key = process.env["LOVABLE_API_KEY"];
  if (!key) {
    throw new Error("Lovable AI is not enabled for this workspace (server key missing).");
  }
  return key;
}

function normalizeBaseUrl(raw: string): string {
  return `${raw.replace(/\/+$/, "").replace(/\/v1$/, "")}/v1`;
}

function statusOf(error: unknown): number | undefined {
  const candidate = error as { statusCode?: unknown; status?: unknown };
  const raw = candidate?.statusCode ?? candidate?.status;
  return typeof raw === "number" && Number.isFinite(raw) ? raw : undefined;
}

/**
 * Turns a gateway failure into something a clinician can act on. The safe
 * upstream message is kept for 402/403 because it names the remedy; anything
 * else is replaced by a generic line. Values are redacted before they reach
 * the UI.
 */
export function describeAiFailure(error: unknown): string {
  const status = statusOf(error);
  const detail =
    error instanceof Error ? redactSensitive(error.message).replace(/\s+/g, " ").slice(0, 300) : "";

  if (status === 401) {
    return "Lovable AI is not configured for this workspace. Ask a workspace admin to enable it.";
  }
  if (status === 402) return detail || "Lovable AI credits are exhausted for this workspace.";
  if (status === 403) return detail || "Lovable AI is not permitted to answer this request.";
  if (status === 404) return "The AI model is unavailable right now. Try again later.";
  if (status === 400) return "The AI could not process this request. Try a narrower question.";
  if (status === 429) return "The AI service is busy. Please wait a moment and try again.";
  if (status && status >= 500) {
    return "The AI service is temporarily unavailable. Please try again shortly.";
  }
  return detail || "The AI could not complete this request.";
}

/**
 * Streams one completion and returns the final text. Callers that only need
 * the finished answer (every Roshan assistant today) consume the stream here
 * rather than leaving a buffered browser request open.
 */
export async function completeAiText(call: AiTextCall): Promise<string> {
  const apiKey = requireLovableApiKey();
  const runIdFetch = createLovableAiGatewayRunIdFetch(undefined);

  const provider = createOpenAI({
    baseURL: normalizeBaseUrl(GATEWAY_BASE_URL),
    apiKey,
    headers: { "Lovable-API-Key": apiKey, "X-Lovable-AIG-SDK": "vercel-ai-sdk" },
    fetch: runIdFetch.fetch,
  });

  const messages: ModelMessage[] = [{ role: "user", content: call.prompt }];

  const result = streamText({
    model: provider.responses(AI_MODEL_ID),
    instructions: call.instructions,
    messages,
    maxOutputTokens: call.maxOutputTokens ?? DEFAULT_MAX_OUTPUT_TOKENS,
    maxRetries: 0,
    providerOptions: {
      openai: {
        store: false,
        forceReasoning: true,
        reasoningEffort: "low",
        reasoningSummary: "auto",
        include: ["reasoning.encrypted_content"],
      },
    },
  });

  // `result.text` consumes the stream to completion server-side.
  const text = (await result.text) ?? "";
  const trimmed = text.trim();
  if (!trimmed) {
    throw new Error("The AI returned an empty answer. Please try again.");
  }
  return trimmed;
}
