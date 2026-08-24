import type { Static } from "typebox";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import { JSDOM } from "jsdom";
import { Readability } from "@mozilla/readability";

const DEFAULT_KAGI_BASE_URL = "https://kagi.com/api/v1";
const DEFAULT_FETCH_TIMEOUT_MS = 15_000;
const DEFAULT_FETCH_MAX_BYTES = 2_000_000;
const DEFAULT_FETCH_MAX_CHARS = 20_000;
const DEFAULT_USER_AGENT =
  "Mozilla/5.0 (compatible; pi-minimal-web/1.0; +https://example.invalid/pi-minimal-web)";

const webSearchSchema = Type.Object({
  query: Type.String({ description: "Search query" }),
  limit: Type.Optional(Type.Number({ description: "Maximum number of results to return (1-10)" })),
  country: Type.Optional(Type.String({ description: "Optional country code hint, e.g. us" })),
  language: Type.Optional(Type.String({ description: "Optional language code hint, e.g. en" })),
});

const webFetchSchema = Type.Object({
  url: Type.String({ description: "HTTP or HTTPS URL to fetch" }),
  maxChars: Type.Optional(
    Type.Number({ description: "Maximum number of characters to return (1000-100000)" }),
  ),
});

type WebSearchInput = Static<typeof webSearchSchema>;
type WebFetchInput = Static<typeof webFetchSchema>;

type SearchResult = {
  title: string;
  url: string;
  snippet?: string;
};

type WebFetchResult = {
  url: string;
  finalUrl: string;
  title?: string;
  byline?: string;
  siteName?: string;
  excerpt?: string;
  content: string;
  truncated: boolean;
};

function getEnvInt(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function getKagiBaseUrl(): string {
  // Requests to this base URL carry the Kagi API key in an Authorization
  // header, so only honor overrides that still point at kagi.com — anything
  // else would leak the key to an arbitrary host.
  const override = process.env.KAGI_BASE_URL?.trim().replace(/\/$/, "");
  if (override) {
    try {
      const parsed = new URL(override);
      const host = parsed.hostname.toLowerCase();
      if (parsed.protocol === "https:" && (host === "kagi.com" || host.endsWith(".kagi.com"))) {
        return override;
      }
    } catch {
      /* fall through to the default */
    }
  }
  return DEFAULT_KAGI_BASE_URL;
}

function getFetchTimeoutMs(): number {
  return getEnvInt("WEB_FETCH_TIMEOUT_MS", DEFAULT_FETCH_TIMEOUT_MS);
}

function getFetchMaxBytes(): number {
  return getEnvInt("WEB_FETCH_MAX_BYTES", DEFAULT_FETCH_MAX_BYTES);
}

function getUserAgent(): string {
  return process.env.WEB_FETCH_USER_AGENT?.trim() || DEFAULT_USER_AGENT;
}

export function resolveKagiApiKey(): string {
  const inline = process.env.KAGI_API_KEY?.trim();
  if (inline) return inline;

  const path = process.env.KAGI_API_KEY_FILE?.trim();
  if (path) {
    const fromFile = readFileSync(path, "utf8").trim();
    if (fromFile) return fromFile;
  }

  throw new Error("Kagi API key not configured. Set KAGI_API_KEY or KAGI_API_KEY_FILE.");
}

function combineSignals(...signals: Array<AbortSignal | undefined>): AbortSignal | undefined {
  const active = signals.filter(Boolean) as AbortSignal[];
  if (active.length === 0) return undefined;
  if (active.length === 1) return active[0];

  // AbortSignal.any (Node 20.3+/Bun) handles listener lifetimes for us.
  if (typeof AbortSignal.any === "function") {
    return AbortSignal.any(active);
  }

  // Fallback: detach our listeners from the caller-owned signals as soon as
  // one of them fires, so we don't accumulate listeners on long-lived signals.
  const controller = new AbortController();
  const cleanups: Array<() => void> = [];
  const abort = (signal: AbortSignal) => {
    if (controller.signal.aborted) return;
    const reason = "reason" in signal ? signal.reason : undefined;
    controller.abort(reason);
    for (const cleanup of cleanups) cleanup();
  };

  for (const signal of active) {
    if (signal.aborted) {
      abort(signal);
      break;
    }
    const onAbort = () => abort(signal);
    signal.addEventListener("abort", onAbort, { once: true });
    cleanups.push(() => signal.removeEventListener("abort", onAbort));
  }

  return controller.signal;
}

function withTimeout(signal: AbortSignal | undefined, ms: number): AbortSignal | undefined {
  return combineSignals(signal, AbortSignal.timeout(ms));
}

function clamp(value: number | undefined, fallback: number, min: number, max: number): number {
  const actual = Number.isFinite(value) ? Number(value) : fallback;
  return Math.min(max, Math.max(min, actual));
}

function normalizeWhitespace(text: string): string {
  return text
    .replace(/\r/g, "")
    .replace(/\t/g, " ")
    .replace(/[ \u00a0]+\n/g, "\n")
    .replace(/\n[ \u00a0]+/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \u00a0]{2,}/g, " ")
    .trim();
}

function decodeHtmlEntities(text: string): string {
  // &amp; must be decoded LAST, otherwise "&amp;lt;" would double-decode to
  // "<" instead of the literal "&lt;" the document meant.
  return text
    .replace(/&#(\d+);/g, (_m, code) => String.fromCodePoint(Number.parseInt(code, 10)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_m, code) => String.fromCodePoint(Number.parseInt(code, 16)))
    .replace(/&nbsp;/g, " ")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

function truncate(text: string, maxChars: number): { content: string; truncated: boolean } {
  if (text.length <= maxChars) return { content: text, truncated: false };
  return {
    content: `${text.slice(0, Math.max(0, maxChars - 18)).trimEnd()}\n\n[truncated]`,
    truncated: true,
  };
}

function requireHttpUrl(url: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error(`Invalid URL: ${url}`);
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error(`Unsupported URL scheme: ${parsed.protocol}`);
  }

  return parsed;
}

function isPrivateIPv4(address: string): boolean {
  const octets = address.split(".").map((part) => Number.parseInt(part, 10));
  if (octets.length !== 4 || octets.some((n) => !Number.isInteger(n) || n < 0 || n > 255)) {
    return true; // unparsable: refuse rather than guess
  }
  const [a, b] = octets;
  return (
    a === 0 || // 0.0.0.0/8 ("this network", routes to localhost on Linux)
    a === 10 || // 10.0.0.0/8
    a === 127 || // 127.0.0.0/8 loopback
    (a === 169 && b === 254) || // 169.254.0.0/16 link-local incl. cloud metadata
    (a === 172 && b >= 16 && b <= 31) || // 172.16.0.0/12
    (a === 192 && b === 168) // 192.168.0.0/16
  );
}

function isPrivateAddress(address: string): boolean {
  const family = isIP(address);
  if (family === 4) return isPrivateIPv4(address);
  if (family !== 6) return true; // unparsable: refuse rather than guess

  const normalized = address.toLowerCase();
  // IPv4-mapped/compatible addresses (::ffff:10.0.0.1) inherit the IPv4 rules.
  const v4Match = normalized.match(/(\d+\.\d+\.\d+\.\d+)$/);
  if (v4Match) return isPrivateIPv4(v4Match[1]);

  if (normalized === "::" || normalized === "::1") return true; // unspecified / loopback
  const firstGroup = Number.parseInt(normalized.split(":")[0] || "0", 16);
  if ((firstGroup & 0xfe00) === 0xfc00) return true; // fc00::/7 unique local
  if ((firstGroup & 0xffc0) === 0xfe80) return true; // fe80::/10 link-local
  return false;
}

/**
 * SSRF guard for web_fetch: resolve the URL's host and reject anything that
 * points at private, loopback, link-local, or metadata address space.
 */
async function assertPublicHost(url: URL): Promise<void> {
  const hostname = url.hostname.replace(/^\[|\]$/g, ""); // URL keeps [] around IPv6 hosts
  const addresses: string[] = [];

  if (isIP(hostname)) {
    addresses.push(hostname);
  } else {
    let resolved: Array<{ address: string }>;
    try {
      resolved = await lookup(hostname, { all: true });
    } catch {
      throw new Error(`Could not resolve host: ${hostname}`);
    }
    if (resolved.length === 0) {
      throw new Error(`Could not resolve host: ${hostname}`);
    }
    addresses.push(...resolved.map((entry) => entry.address));
  }

  for (const address of addresses) {
    if (isPrivateAddress(address)) {
      throw new Error(`Refusing to fetch non-public address: ${hostname} (${address})`);
    }
  }
}

function stringifySearchResults(query: string, results: SearchResult[]): string {
  if (results.length === 0) return `No web results found for: ${query}`;

  return [
    `Kagi web results for: ${query}`,
    ...results.map((result, index) => {
      const parts = [`${index + 1}. ${result.title}`, result.url];
      if (result.snippet) parts.push(result.snippet);
      return parts.join("\n");
    }),
  ].join("\n\n");
}

function normalizeKagiResults(payload: any): SearchResult[] {
  const candidates = [
    ...(Array.isArray(payload?.data) ? payload.data : []),
    ...(Array.isArray(payload?.data?.search) ? payload.data.search : []),
    ...(Array.isArray(payload?.results) ? payload.results : []),
    ...(Array.isArray(payload?.web?.results) ? payload.web.results : []),
  ];

  return candidates
    .map((item: any) => {
      const title = item?.title || item?.t || item?.name;
      const url = item?.url || item?.u || item?.link || item?.href;
      const snippet = item?.snippet || item?.desc || item?.description || item?.body;
      if (!title || !url) return null;
      return {
        title: decodeHtmlEntities(String(title)).trim(),
        url: String(url).trim(),
        snippet: snippet ? decodeHtmlEntities(normalizeWhitespace(String(snippet))) : undefined,
      };
    })
    .filter(Boolean) as SearchResult[];
}

export async function runWebSearch(
  params: WebSearchInput,
  signal?: AbortSignal,
): Promise<{ query: string; provider: "kagi"; results: SearchResult[] }> {
  const limit = clamp(params.limit, 5, 1, 10);
  const key = resolveKagiApiKey();
  const url = new URL(`${getKagiBaseUrl()}/search`);

  let response: Response;
  try {
    response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bot ${key}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        "User-Agent": getUserAgent(),
      },
      body: JSON.stringify({
        query: params.query,
        limit,
        country: params.country,
        language: params.language,
      }),
      signal: withTimeout(signal, getFetchTimeoutMs()),
    });
  } catch (error) {
    if (error instanceof Error && error.name === "TimeoutError") {
      throw new Error("Kagi request timed out");
    }
    throw error;
  }

  if (response.status === 401 || response.status === 403) {
    throw new Error("Kagi authentication failed");
  }
  if (response.status === 429) {
    throw new Error("Kagi rate limit reached");
  }
  if (!response.ok) {
    throw new Error(`Kagi search failed with HTTP ${response.status}`);
  }

  const payload = await response.json();
  return {
    query: params.query,
    provider: "kagi",
    results: normalizeKagiResults(payload).slice(0, limit),
  };
}

function isTextLikeContentType(contentType: string): boolean {
  const normalized = contentType.toLowerCase();
  return (
    normalized.includes("text/plain") ||
    normalized.includes("text/markdown") ||
    normalized.includes("text/x-markdown") ||
    normalized.includes("application/json") ||
    normalized.includes("application/yaml") ||
    normalized.includes("application/x-yaml") ||
    normalized.includes("text/yaml") ||
    normalized.includes("text/x-yaml")
  );
}

function shouldUseKagiExtract(url: string): boolean {
  if (process.env.WEB_FETCH_USE_KAGI_EXTRACT === "false") return false;
  try {
    return new URL(url).protocol === "https:";
  } catch {
    return false;
  }
}

type KagiExtractResult = {
  finalUrl: string;
  markdown: string;
};

async function runKagiExtract(
  url: string,
  signal?: AbortSignal,
): Promise<KagiExtractResult | null> {
  const key = resolveKagiApiKey();
  const endpoint = `${getKagiBaseUrl()}/extract`;
  const timeoutSeconds = Math.min(Math.max(1, getFetchTimeoutMs() / 1000), 60);

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bot ${key}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        "User-Agent": getUserAgent(),
      },
      body: JSON.stringify({
        pages: [{ url }],
        format: "json",
        timeout: timeoutSeconds,
      }),
      signal: withTimeout(signal, getFetchTimeoutMs()),
    });
  } catch (error) {
    if (error instanceof Error && error.name === "TimeoutError") {
      throw new Error("Kagi extract timed out");
    }
    throw error;
  }

  if (response.status === 401 || response.status === 403) {
    throw new Error("Kagi authentication failed");
  }
  if (response.status === 429) {
    throw new Error("Kagi rate limit reached");
  }
  if (!response.ok) {
    return null;
  }

  const payload = await response.json();
  const page = payload?.data?.[0];
  if (!page || page.error || !page.markdown) {
    return null;
  }

  return {
    finalUrl: page.url || url,
    markdown: page.markdown,
  };
}

const MAX_REDIRECTS = 5;

async function fetchText(
  url: string,
  signal?: AbortSignal,
): Promise<{ finalUrl: string; contentType: string; body: string }> {
  // Follow redirects manually so every hop — not just the first URL — gets
  // the SSRF check; a public host could otherwise redirect us to
  // localhost/metadata endpoints.
  const timeoutSignal = withTimeout(signal, getFetchTimeoutMs());
  let currentUrl = requireHttpUrl(url);
  let response: Response;
  for (let redirects = 0; ; redirects++) {
    await assertPublicHost(currentUrl);
    response = await fetch(currentUrl, {
      method: "GET",
      redirect: "manual",
      headers: {
        "User-Agent": getUserAgent(),
        Accept: "text/html, text/plain, text/markdown, application/xhtml+xml;q=0.9, */*;q=0.1",
      },
      signal: timeoutSignal,
    });

    const location = response.headers.get("location");
    if (response.status < 300 || response.status >= 400 || !location) break;
    if (redirects >= MAX_REDIRECTS) {
      throw new Error(`Too many redirects (more than ${MAX_REDIRECTS})`);
    }
    try {
      await response.body?.cancel();
    } catch {
      /* ignore */
    }
    currentUrl = requireHttpUrl(new URL(location, currentUrl).toString());
  }

  if (!response.ok) {
    throw new Error(`Fetch failed with HTTP ${response.status}`);
  }

  // Enforce the byte cap while streaming instead of after buffering the whole
  // body, so a huge document can't exhaust memory. The Content-Length check
  // is just a fast path; servers may omit or understate it.
  const maxBytes = getFetchMaxBytes();
  const contentLength = Number(response.headers.get("content-length"));
  if (Number.isFinite(contentLength) && contentLength > maxBytes) {
    throw new Error(`Fetched document exceeds WEB_FETCH_MAX_BYTES (${maxBytes})`);
  }

  const chunks: Buffer[] = [];
  let received = 0;
  if (response.body) {
    const reader = response.body.getReader();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      received += value.byteLength;
      if (received > maxBytes) {
        await reader.cancel();
        throw new Error(`Fetched document exceeds WEB_FETCH_MAX_BYTES (${maxBytes})`);
      }
      chunks.push(Buffer.from(value));
    }
  }
  const body = Buffer.concat(chunks).toString("utf8");

  return {
    finalUrl: response.url,
    contentType: response.headers.get("content-type") || "",
    body,
  };
}

function htmlToReadableText(finalUrl: string, html: string) {
  const dom = new JSDOM(html, { url: finalUrl });
  const document = dom.window.document;
  const reader = new Readability(document);
  const article = reader.parse();
  const fallbackText = normalizeWhitespace(document.body?.textContent || "");

  return {
    title: article?.title || document.title || undefined,
    byline: article?.byline || undefined,
    siteName: article?.siteName || undefined,
    excerpt: article?.excerpt || undefined,
    content: normalizeWhitespace(article?.textContent || fallbackText),
  };
}

export async function runWebFetch(
  params: WebFetchInput,
  signal?: AbortSignal,
): Promise<WebFetchResult> {
  const requestedUrl = requireHttpUrl(params.url).toString();
  const maxChars = clamp(params.maxChars, DEFAULT_FETCH_MAX_CHARS, 1_000, 100_000);

  let extracted:
    | {
        title?: string;
        byline?: string;
        siteName?: string;
        excerpt?: string;
        content: string;
      }
    | undefined;
  let finalUrl = requestedUrl;

  // Prefer Kagi Extract for HTTPS pages; fall back to local fetch if it fails or is unavailable.
  if (shouldUseKagiExtract(requestedUrl)) {
    try {
      const kagiResult = await runKagiExtract(requestedUrl, signal);
      if (kagiResult) {
        extracted = { content: normalizeWhitespace(kagiResult.markdown) };
        finalUrl = kagiResult.finalUrl;
      }
    } catch (error) {
      if (
        error instanceof Error &&
        (error.message === "Kagi authentication failed" ||
          error.message === "Kagi rate limit reached" ||
          error.message === "Kagi extract timed out")
      ) {
        throw error;
      }
      // Otherwise fall through to local fetch.
    }
  }

  if (!extracted) {
    let fetched: { finalUrl: string; contentType: string; body: string };
    try {
      fetched = await fetchText(requestedUrl, signal);
    } catch (error) {
      if (error instanceof Error && error.name === "TimeoutError") {
        throw new Error("Web fetch timed out");
      }
      throw error;
    }

    finalUrl = fetched.finalUrl;

    if (
      fetched.contentType.toLowerCase().includes("text/html") ||
      fetched.contentType.toLowerCase().includes("application/xhtml+xml")
    ) {
      extracted = htmlToReadableText(fetched.finalUrl, fetched.body);
    } else if (isTextLikeContentType(fetched.contentType)) {
      extracted = { content: normalizeWhitespace(fetched.body) };
    } else {
      throw new Error(`Unsupported content type: ${fetched.contentType || "unknown"}`);
    }
  }

  if (!extracted.content) {
    throw new Error("Failed to extract readable content from page");
  }

  const truncated = truncate(extracted.content, maxChars);
  return {
    url: requestedUrl,
    finalUrl,
    title: extracted.title,
    byline: extracted.byline,
    siteName: extracted.siteName,
    excerpt: extracted.excerpt,
    content: truncated.content,
    truncated: truncated.truncated,
  };
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description: "Search the web with Kagi and return privacy-respecting search results.",
    promptSnippet: "Search the live web using Kagi when you need current external information.",
    promptGuidelines: [
      "Use web_search when the user asks for current web information, sources, or recent facts beyond local files.",
      "Use web_search before guessing when authoritative web sources are needed.",
    ],
    parameters: webSearchSchema,
    async execute(_toolCallId, params, signal) {
      const result = await runWebSearch(params, signal);
      return {
        content: [{ type: "text", text: stringifySearchResults(result.query, result.results) }],
        details: result,
      };
    },
  });

  pi.registerTool({
    name: "web_fetch",
    label: "Web Fetch",
    description: "Fetch a web page directly and extract readable text content.",
    promptSnippet:
      "Fetch and read a specific web page URL directly when the user wants page contents.",
    promptGuidelines: [
      "Use web_fetch after web_search when you need the actual contents of a specific result page.",
      "Use web_fetch for direct URL reading, article extraction, or verifying the contents of a page.",
    ],
    parameters: webFetchSchema,
    async execute(_toolCallId, params, signal) {
      const result = await runWebFetch(params, signal);
      const header = [
        result.title ? `Title: ${result.title}` : undefined,
        result.byline ? `Byline: ${result.byline}` : undefined,
        result.siteName ? `Site: ${result.siteName}` : undefined,
        result.excerpt ? `Excerpt: ${result.excerpt}` : undefined,
        `URL: ${result.finalUrl}`,
      ]
        .filter(Boolean)
        .join("\n");

      return {
        content: [{ type: "text", text: `${header}\n\n${result.content}` }],
        details: result,
      };
    },
  });
}
