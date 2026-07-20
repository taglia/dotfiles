/**
 * Confirm Interrupt Extension
 *
 * Asks for confirmation before Escape stops/aborts the current run.
 *
 * Behavior:
 * - While a run is in progress (agent streaming / tool running), Escape opens a
 *   confirm dialog instead of aborting immediately. Enter stops the run; Esc
 *   (or "No") continues it.
 * - When idle, Escape keeps its default behavior (double-escape tree/fork,
 *   clearing `!` bash mode, etc.).
 * - Escape still cancels autocomplete as usual (no confirmation).
 *
 * Compatibility:
 * - If another custom editor is already installed (e.g. pi-vim), this extension
 *   wraps it rather than replacing it. It decorates the existing editor's
 *   `onEscape` callback, which is the exact point where pi-vim reaches Pi's abort
 *   path (normal-mode Esc -> `super.handleInput("\x1b")` -> `onEscape`).
 *   Insert->Normal switching and pending-state clearing never call `onEscape`,
 *   so they are left untouched.
 * - If no custom editor is installed, it falls back to a standalone
 *   `CustomEditor` subclass that intercepts Escape directly.
 *
 * Implementation note: pi reserves `app.interrupt` (default: Escape) for built-in
 * keybindings, so `pi.registerShortcut("escape", ...)` is skipped by the loader.
 * The supported way to intercept it is via a custom editor / editor wrapper.
 *
 * Place in ~/.pi/agent/extensions/ (auto-discovered). Run `/reload` in pi to load.
 */

import {
  CustomEditor,
  type EditorFactory,
  type ExtensionAPI,
  type ExtensionContext,
  type KeybindingsManager,
} from "@earendil-works/pi-coding-agent";
import { matchesKey, type EditorTheme, type TUI } from "@earendil-works/pi-tui";

/** Marker so we can unwrap our own factory on reload and avoid nesting. */
const CONFIRM_INTERRUPT = Symbol("confirmInterrupt");

/**
 * Decorate an existing editor's `onEscape` so aborting requires confirmation.
 * `onEscape` is the callback Pi's CustomEditor calls for the interrupt action.
 */
function confirmInterruptOnEscape(
  editor: { onEscape?: () => void } | undefined,
  ctx: ExtensionContext,
): void {
  if (!editor || typeof editor.onEscape !== "function") return;

  const original = editor.onEscape;
  let confirming = false;

  editor.onEscape = () => {
    // A confirm dialog is already open; it owns input now. Ignore repeats.
    if (confirming) return;

    // Nothing to interrupt: keep default Escape behavior.
    if (ctx.isIdle()) {
      original();
      return;
    }

    // Run in progress: confirm before interrupting.
    confirming = true;
    void ctx.ui
      .confirm("Stop current run?", "Press Enter to stop, Esc to continue.")
      .then((stop) => {
        confirming = false;
        if (stop) {
          original();
        } else {
          ctx.ui.notify("Continuing", "info");
        }
      });
  };
}

/**
 * Standalone editor used when no other custom editor (pi-vim, etc.) is installed.
 */
class ConfirmInterruptEditor extends CustomEditor {
  private readonly ctx: ExtensionContext;
  private confirming = false;

  constructor(
    tui: TUI,
    theme: EditorTheme,
    keybindings: KeybindingsManager,
    ctx: ExtensionContext,
  ) {
    super(tui, theme, keybindings);
    this.ctx = ctx;
  }

  handleInput(data: string): void {
    // Let Escape cancel autocomplete first (default behavior, no confirmation).
    if (this.isShowingAutocomplete()) {
      super.handleInput(data);
      return;
    }

    if (matchesKey(data, "escape")) {
      if (this.confirming) return;

      // Nothing to interrupt: keep default Escape behavior.
      if (this.ctx.isIdle()) {
        super.handleInput(data);
        return;
      }

      // Run in progress: confirm before interrupting.
      this.confirming = true;
      void this.askConfirm().finally(() => {
        this.confirming = false;
      });
      return;
    }

    super.handleInput(data);
  }

  private async askConfirm(): Promise<void> {
    const stop = await this.ctx.ui.confirm(
      "Stop current run?",
      "Press Enter to stop, Esc to continue.",
    );
    if (stop) {
      // Default interrupt handler: aborts model/bash and restores queued messages.
      this.onEscape?.();
    } else {
      this.ctx.ui.notify("Continuing", "info");
    }
  }
}

export default function confirmInterruptExtension(pi: ExtensionAPI) {
  // NOTE: We wrap on resources_discover (not session_start) because extension load
  // order is sorted by precedence: user auto-discovered extensions (rank 3)
  // load before package extensions (rank 4), so pi-vim's session_start runs
  // AFTER ours and would overwrite an editor we set in session_start.
  // resources_discover fires after all session_start handlers, so the vim
  // editor factory is already registered when we wrap it.
  pi.on("resources_discover", (_event, ctx) => {
    // Custom editor is TUI-only.
    if (ctx.mode !== "tui") return;

    let previous = ctx.ui.getEditorComponent();

    // On reload, our own wrapper factory may still be registered. Unwrap to the
    // underlying editor factory so we don't nest wrappers.
    if (previous && (previous as any)[CONFIRM_INTERRUPT]) {
      previous = (previous as any).previous as EditorFactory | undefined;
    }

    if (previous) {
      // Wrap the existing custom editor (e.g. pi-vim) in place.
      const factory = ((tui: TUI, theme: EditorTheme, kb: KeybindingsManager) => {
        const editor = previous!(tui, theme, kb);
        // Pi's setEditorComponent wires `onEscape` after this factory returns.
        // Decorate it on the next microtask so we wrap the wired handler.
        queueMicrotask(() => confirmInterruptOnEscape(editor as { onEscape?: () => void }, ctx));
        return editor;
      }) as EditorFactory & { [CONFIRM_INTERRUPT]: true; previous: EditorFactory | undefined };
      factory[CONFIRM_INTERRUPT] = true;
      factory.previous = previous;
      ctx.ui.setEditorComponent(factory);
    } else {
      // No custom editor installed: use the standalone intercepting editor.
      ctx.ui.setEditorComponent(
        (tui, theme, keybindings) => new ConfirmInterruptEditor(tui, theme, keybindings, ctx),
      );
    }
  });
}
