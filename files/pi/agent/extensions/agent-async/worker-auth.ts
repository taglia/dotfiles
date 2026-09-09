import type { Api, Model } from "@earendil-works/pi-ai";
import type { ModelRuntime, ModelRegistry } from "@earendil-works/pi-coding-agent";

type RequestAuth = Extract<Awaited<ReturnType<ModelRegistry["getApiKeyAndHeaders"]>>, { ok: true }>;

/** Bind one pre-authorized model to a literal, in-memory request-auth snapshot.
 * OAuth-only providers do not recognize setRuntimeApiKey as configured auth.
 * Never pass resolved secrets through models.json's !command/$ENV interpolation.
 * Refresh tokens, credential stores, and executable provider code stay in the parent.
 */
export async function configureWorkerModel(
  runtime: ModelRuntime,
  model: Model<Api>,
  auth: RequestAuth,
): Promise<Model<Api>> {
  if (!auth.ok || (auth.env && Object.keys(auth.env).length))
    throw new Error("Unsupported worker authentication snapshot");
  // The parent already resolved model/provider headers into auth.headers. Keeping
  // model.headers here would re-evaluate their config expressions in the worker.
  const selected = { ...model, baseUrl: auth.baseUrl ?? model.baseUrl };
  delete selected.headers;
  const requestAuth = {
    apiKey: auth.apiKey,
    headers: auth.headers ? { ...auth.headers } : undefined,
    baseUrl: auth.baseUrl,
  };

  // Use only Pi's bundled API implementation and the explicitly selected model.
  runtime.registerProvider(model.provider, {
    api: model.api,
    baseUrl: selected.baseUrl,
    models: [selected],
  });
  const adapter = runtime.getProvider(model.provider);
  if (!adapter) throw new Error("Selected provider could not be reproduced in worker");
  runtime.registerNativeProvider({
    ...adapter,
    getModels: () => [selected],
    refreshModels: undefined,
    filterModels: undefined,
    auth: {
      apiKey: {
        name: "Supervisor request credential",
        async login() {
          throw new Error("Workers cannot log in; authentication belongs to the supervisor");
        },
        async resolve({ signal }) {
          signal.throwIfAborted();
          return { source: "supervisor request snapshot", auth: requestAuth };
        },
      },
    },
  });
  // Check through the same path used by session.prompt, including OAuth-only providers.
  if (!(await runtime.checkAuth(model.provider)))
    throw new Error("Worker authentication snapshot was not recognized");
  const resolved = runtime.getModel(model.provider, model.id);
  if (!resolved || resolved.api !== model.api)
    throw new Error("Selected model could not be reproduced in worker; no fallback allowed.");
  return resolved;
}
