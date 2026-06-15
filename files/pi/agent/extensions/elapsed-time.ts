import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function formatElapsed(ms: number): string {
	if (ms < 1000) return `${ms}ms`;
	if (ms < 10_000) return `${(ms / 1000).toFixed(1)}s`;
	if (ms < 60_000) return `${Math.round(ms / 1000)}s`;

	const minutes = Math.floor(ms / 60_000);
	const seconds = ((ms % 60_000) / 1000).toFixed(1);
	return `${minutes}m ${seconds}s`;
}

export default function (pi: ExtensionAPI) {
	let lastUserPromptAt: number | null = null;

	pi.on("message_start", async (event) => {
		if (event.message.role === "user") {
			lastUserPromptAt = event.message.timestamp;
		}
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (lastUserPromptAt == null) return;

		const elapsedMs = Math.max(0, Date.now() - lastUserPromptAt);
		ctx.ui.notify(`Elapsed: ${formatElapsed(elapsedMs)}`, "info");
	});
}
