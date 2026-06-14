import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { Container, Text } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    const artPath = join(homedir(), ".pi/agent/ascii-art/taglia-pi.txt");
    let art: string;
    try {
      art = readFileSync(artPath, "utf8").replace(/\n$/, "");
    } catch {
      return;
    }

    const lines = art.split("\n");
    ctx.ui.setWidget(
      "ascii-header",
      () => {
        const container = new Container();
        for (const line of lines) container.addChild(new Text(line, 1, 0));
        return container;
      },
      { placement: "aboveEditor" },
    );
  });

  // Remove the ASCII header once the user submits their first prompt.
  pi.on("input", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.setWidget("ascii-header", undefined);
  });
}
