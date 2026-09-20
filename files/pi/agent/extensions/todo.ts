/**
 * Branch-local task list, persisted as validated snapshots in tool results.
 * Adapted from pi's bundled examples/extensions/todo.ts (MIT).
 */
import { StringEnum } from "@earendil-works/pi-ai";
import {
  truncateHead,
  type ExtensionAPI,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  type Component,
  matchesKey,
  Text,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";
import { Type } from "typebox";

const ACTIONS = ["list", "add", "update", "remove", "clear"] as const;
const STATUSES = ["pending", "in_progress", "done"] as const;
type Action = (typeof ACTIONS)[number];
type Status = (typeof STATUSES)[number];
interface Task {
  id: number;
  text: string;
  status: Status;
}
interface Snapshot {
  tasks: Task[];
  nextId: number;
}
interface TodoDetails extends Snapshot {
  version: 1;
  action: Action;
  affectedIds?: number[];
  offset?: number;
  limit?: number;
}
const MAX_TASKS = 500;
const MAX_TEXT_LENGTH = 1000;
const MAX_BATCH = 100;
const PAGE_SIZE = 20;
const WIDGET_KEY = "todo";
const WIDGET_MAX_TASKS = 10;

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}
function positiveId(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0;
}
function pageOffset(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
}
function pageLimit(value: unknown): value is number {
  return positiveId(value) && value <= 100;
}
function action(value: unknown): value is Action {
  return typeof value === "string" && ACTIONS.includes(value as Action);
}
function status(value: unknown): value is Status {
  return typeof value === "string" && STATUSES.includes(value as Status);
}

// Accept original unversioned snapshots without rewriting history. Limits for
// new mutations do not discard legitimate older, larger lists or task labels.
function decodeSnapshot(value: unknown): Snapshot | undefined {
  const data = record(value);
  if (!data || (data.version !== undefined && data.version !== 1)) return;
  if (!Array.isArray(data.tasks) || !positiveId(data.nextId)) return;
  const tasks: Task[] = [];
  const ids = new Set<number>();
  for (const item of data.tasks) {
    const task = record(item);
    if (
      !task ||
      !positiveId(task.id) ||
      ids.has(task.id) ||
      task.id >= data.nextId ||
      typeof task.text !== "string" ||
      !status(task.status)
    )
      return;
    ids.add(task.id);
    tasks.push({ id: task.id, text: task.text, status: task.status });
  }
  return { tasks, nextId: data.nextId };
}

// Strip terminal escape sequences as well as raw control characters. Persisted
// legacy labels remain intact; their display is always safe and single-line.
function displayText(text: string): string {
  return text
    .replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g, "")
    .replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/g, " ");
}
function cleanText(value: unknown): string {
  if (typeof value !== "string") throw new Error("Task text must be a string");
  const text = displayText(value).trim();
  if (!text) throw new Error("Task text must not be empty");
  if (text.length > MAX_TEXT_LENGTH)
    throw new Error(`Task text must be at most ${MAX_TEXT_LENGTH} characters`);
  return text;
}
function resultText(content: unknown): string {
  if (!Array.isArray(content)) return "";
  return content
    .flatMap((block) => {
      const item = record(block);
      return item?.type === "text" && typeof item.text === "string" ? [item.text] : [];
    })
    .join("\n");
}
function boundedText(text: string): string {
  // Reserve space for the truncation notice within pi's 50KB/2000-line cap.
  const output = truncateHead(text, { maxBytes: 49 * 1024, maxLines: 1999 });
  return output.content + (output.truncated ? "\n… output truncated; use a smaller list page" : "");
}
function plainText(text: string): string {
  return boundedText(text).split("\n").map(displayText).join("\n");
}

const TodoParams = Type.Object({
  action: StringEnum(ACTIONS),
  text: Type.Optional(Type.String({ description: "Task text to add or replace" })),
  items: Type.Optional(
    Type.Array(Type.String(), { maxItems: MAX_BATCH, description: "Several tasks to add at once" }),
  ),
  id: Type.Optional(
    Type.Integer({
      minimum: 1,
      maximum: Number.MAX_SAFE_INTEGER,
      description: "Task id for update/remove",
    }),
  ),
  status: Type.Optional(StringEnum(STATUSES)),
  offset: Type.Optional(Type.Integer({ minimum: 0, description: "List page offset (default 0)" })),
  limit: Type.Optional(
    Type.Integer({ minimum: 1, maximum: 100, description: "List page size (default 20)" }),
  ),
});
function isDone(task: Task): boolean {
  return task.status === "done";
}
function progress(tasks: Task[]): string {
  return `${tasks.filter(isDone).length}/${tasks.length}`;
}
function renderTask(task: Task, th: Theme): string {
  const id = th.fg("dim", `#${task.id}`);
  const label = displayText(task.text);
  const text = label.length > MAX_TEXT_LENGTH ? `${label.slice(0, MAX_TEXT_LENGTH - 1)}…` : label;
  switch (task.status) {
    case "done":
      return `${th.fg("success", "☑")} ${id} ${th.fg("dim", th.strikethrough(text))}`;
    case "in_progress":
      return `${th.fg("accent", "▣")} ${id} ${th.fg("text", th.bold(text))}`;
    default:
      return `${th.fg("muted", "☐")} ${id} ${th.fg("text", text)}`;
  }
}
function describeTask(task: Task): string {
  const box = task.status === "done" ? "[x]" : task.status === "in_progress" ? "[~]" : "[ ]";
  return `${box} #${task.id} ${displayText(task.text)}`;
}
function header(title: string, tasks: Task[], th: Theme, width: number): string {
  const label = th.fg("accent", th.bold(` ${title} `)) + th.fg("muted", `${progress(tasks)} `);
  const lead = th.fg("borderMuted", "──");
  const fill = Math.max(0, width - visibleWidth(lead) - visibleWidth(label));
  return truncateToWidth(lead + label + th.fg("borderMuted", "─".repeat(fill)), width);
}
function widgetLines(tasks: Task[], th: Theme, width: number): string[] {
  if (width <= 0) return [];
  const shown =
    tasks.length > WIDGET_MAX_TASKS
      ? tasks.filter((t) => !isDone(t)).slice(0, WIDGET_MAX_TASKS)
      : tasks;
  const lines = [header("Tasks", tasks, th, width)];
  for (const task of shown) lines.push(truncateToWidth(`  ${renderTask(task, th)}`, width));
  const hidden = tasks.length - shown.length;
  if (hidden > 0) lines.push(truncateToWidth(`  ${th.fg("dim", `… ${hidden} more`)}`, width));
  return lines;
}

// Bound the editor replacement's height, including for large legacy lists.
class TodoListComponent implements Component {
  private offset = 0;
  constructor(
    private tasks: Task[],
    private theme: Theme,
    private onClose: () => void,
  ) {}
  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "q"))
      this.onClose();
    else if (matchesKey(data, "down") || matchesKey(data, "pageDown"))
      this.offset = Math.min(
        Math.max(0, Math.floor((this.tasks.length - 1) / WIDGET_MAX_TASKS) * WIDGET_MAX_TASKS),
        this.offset + WIDGET_MAX_TASKS,
      );
    else if (matchesKey(data, "up") || matchesKey(data, "pageUp"))
      this.offset = Math.max(0, this.offset - WIDGET_MAX_TASKS);
  }
  render(width: number): string[] {
    if (width <= 0) return [];
    const lines = ["", header("Tasks", this.tasks, this.theme, width), ""];
    if (!this.tasks.length) lines.push(truncateToWidth("  No tasks yet.", width));
    for (const task of this.tasks.slice(this.offset, this.offset + WIDGET_MAX_TASKS))
      lines.push(truncateToWidth(`  ${renderTask(task, this.theme)}`, width));
    lines.push(
      "",
      truncateToWidth(
        this.theme.fg(
          "dim",
          `  ↑/↓ page • Escape closes • ${this.offset + (this.tasks.length ? 1 : 0)}–${Math.min(this.tasks.length, this.offset + WIDGET_MAX_TASKS)}/${this.tasks.length}`,
        ),
        width,
      ),
    );
    return lines;
  }
  invalidate(): void {}
}

export default function (pi: ExtensionAPI) {
  let tasks: Task[] = [];
  let nextId = 1;
  const snapshot = (): Task[] => tasks.map((t) => ({ ...t }));
  const warn = (ctx: ExtensionContext, text: string) => {
    if (!ctx.hasUI) return;
    try {
      ctx.ui.notify(text, "warning");
    } catch {
      /* UI failure is non-fatal. */
    }
  };
  const refreshWidget = (ctx: ExtensionContext) => {
    if (ctx.mode !== "tui") return;
    // UI failure must not prevent persistence of an already committed mutation.
    try {
      const shown = snapshot();
      ctx.ui.setWidget(
        WIDGET_KEY,
        shown.length
          ? (_tui, theme) => ({
              render: (width: number) => widgetLines(shown, theme, width),
              invalidate: () => {},
            })
          : undefined,
      );
    } catch {
      warn(ctx, "Todo widget could not be refreshed; task state was retained.");
    }
  };
  const reconstructState = (ctx: ExtensionContext) => {
    tasks = [];
    nextId = 1;
    let invalid = 0;
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message") continue;
      const msg = entry.message;
      if (msg.role !== "toolResult" || msg.toolName !== "todo" || msg.isError) continue;
      const restored = decodeSnapshot(msg.details);
      if (restored) {
        tasks = restored.tasks;
        nextId = restored.nextId;
      } else invalid++;
    }
    if (invalid)
      warn(ctx, `Skipped ${invalid} invalid todo snapshot(s); restored the latest valid state.`);
    refreshWidget(ctx);
  };
  pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
  pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));

  const result = (
    action: Action,
    text: string,
    metadata: Pick<TodoDetails, "affectedIds" | "offset" | "limit"> = {},
  ) => ({
    content: [{ type: "text" as const, text: boundedText(text) }],
    details: { version: 1, action, tasks: snapshot(), nextId, ...metadata } satisfies TodoDetails,
  });

  pi.registerTool({
    name: "todo",
    label: "Todo",
    description:
      "Task list for the current session. Actions: list (offset, limit; default 20, max 100); " +
      "add (text or items); update (id, status and/or text); remove (id); clear. " +
      "Statuses: pending, in_progress, done. Limits: 500 tasks, 100 per add, 1000 characters per task. " +
      "Output capped at 50KB/2000 lines; use smaller list pages if truncated.",
    promptSnippet: "Plan and track multi-step work as a task list the user can see",
    promptGuidelines: [
      "Use todo to record the steps of any multi-step task before starting, mark each step " +
        "in_progress when you begin it and done when it is finished, and keep the list current " +
        "instead of restating the plan in prose.",
    ],
    parameters: TodoParams,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      signal?.throwIfAborted();
      // Hooks may modify arguments after pi's schema validation. Validate all
      // relevant fields again before mutating, and keep the commit synchronous.
      if (!record(params) || !action(params.action)) throw new Error("Unknown todo action");
      const finish = (action: Action, text: string, affectedIds?: number[]) => {
        const output = result(action, text, { affectedIds });
        refreshWidget(ctx);
        return output;
      };
      switch (params.action) {
        case "list": {
          const offset = params.offset ?? 0;
          const limit = params.limit ?? PAGE_SIZE;
          if (!pageOffset(offset) || !pageLimit(limit))
            throw new Error("List requires a nonnegative integer offset and limit 1–100");
          const page = tasks.slice(offset, offset + limit);
          let text = page.length
            ? page.map(describeTask).join("\n")
            : tasks.length
              ? "No tasks on this page"
              : "No tasks";
          if (tasks.length > page.length)
            text += `\nShowing ${page.length} of ${tasks.length} tasks (offset ${offset}).`;
          if (offset + page.length < tasks.length && page.length)
            text += ` Next offset: ${offset + page.length}.`;
          return result("list", text, { offset, limit });
        }
        case "add": {
          if (params.items !== undefined && !Array.isArray(params.items))
            throw new Error("items must be an array of task strings");
          const texts: unknown[] = [
            ...(params.items ?? []),
            ...(params.text !== undefined ? [params.text] : []),
          ];
          if (!texts.length || texts.length > MAX_BATCH)
            throw new Error(`Provide 1–${MAX_BATCH} tasks via text or items`);
          if (tasks.length + texts.length > MAX_TASKS)
            throw new Error(`Maximum ${MAX_TASKS} tasks; remove or clear tasks first`);
          if (!Number.isSafeInteger(nextId + texts.length))
            throw new Error("Task ID space exhausted");
          const added = texts.map((value, index) => ({
            id: nextId + index,
            text: cleanText(value),
            status: "pending" as const,
          }));
          tasks = [...tasks, ...added];
          nextId += added.length;
          return finish(
            "add",
            added.map((t) => `Added #${t.id}: ${t.text}`).join("\n"),
            added.map((t) => t.id),
          );
        }
        case "update": {
          if (!positiveId(params.id)) throw new Error("A positive integer task id is required");
          const index = tasks.findIndex((t) => t.id === params.id);
          if (index < 0) throw new Error(`Task #${params.id} not found`);
          if (params.status === undefined && params.text === undefined)
            throw new Error("status or text required");
          if (params.status !== undefined && !status(params.status))
            throw new Error("Invalid task status");
          const updated = {
            ...tasks[index],
            ...(params.status !== undefined ? { status: params.status } : {}),
            ...(params.text !== undefined ? { text: cleanText(params.text) } : {}),
          };
          tasks = tasks.map((task, i) => (i === index ? updated : task));
          return finish("update", describeTask(updated), [updated.id]);
        }
        case "remove": {
          if (!positiveId(params.id)) throw new Error("A positive integer task id is required");
          const removed = tasks.find((t) => t.id === params.id);
          if (!removed) throw new Error(`Task #${params.id} not found`);
          tasks = tasks.filter((t) => t.id !== removed.id);
          return finish("remove", `Removed #${removed.id}: ${displayText(removed.text)}`, [
            removed.id,
          ]);
        }
        case "clear": {
          const count = tasks.length;
          tasks = [];
          nextId = 1;
          return finish("clear", `Cleared ${count} task(s)`);
        }
      }
    },
    renderCall(args, theme): Component {
      const data = record(args) ?? {};
      let text =
        theme.fg("toolTitle", theme.bold("todo ")) +
        theme.fg("muted", action(data.action) ? data.action : "?");
      if (positiveId(data.id)) text += ` ${theme.fg("accent", `#${data.id}`)}`;
      if (status(data.status)) text += ` ${theme.fg("muted", data.status)}`;
      if (typeof data.text === "string")
        text += ` ${theme.fg("dim", JSON.stringify(displayText(data.text).slice(0, MAX_TEXT_LENGTH)))}`;
      if (Array.isArray(data.items)) text += ` ${theme.fg("dim", `${data.items.length} items`)}`;
      return new Text(text, 0, 0);
    },
    renderResult(result, { expanded }, theme, context): Component {
      const fallback = () =>
        new Text(
          theme.fg(
            context.isError ? "error" : "muted",
            plainText(resultText(result.content)) ||
              (context.isError ? "Todo failed" : "No todo output"),
          ),
          0,
          0,
        );
      // Error/partial results need not contain a snapshot at all.
      if (context.isError || context.isPartial) return fallback();
      const data = record(result.details);
      if (typeof data?.error === "string")
        return new Text(theme.fg("error", plainText(`Error: ${data.error}`)), 0, 0);
      const restored = decodeSnapshot(data);
      if (!data || !restored || !action(data.action)) return fallback();
      const list = restored.tasks;
      switch (data.action) {
        case "list": {
          const offset = data.offset ?? 0;
          const limit = data.limit ?? PAGE_SIZE;
          if (!pageOffset(offset) || !pageLimit(limit)) return fallback();
          if (!list.length) return new Text(theme.fg("dim", "No tasks"), 0, 0);
          const page = list.slice(offset, offset + limit);
          const shown = expanded ? page : page.slice(0, 6);
          let text = theme.fg("muted", `${progress(list)} done`);
          for (const task of shown) text += `\n${renderTask(task, theme)}`;
          if (shown.length < page.length)
            text += `\n${theme.fg("dim", `… ${page.length - shown.length} more on this page`)}`;
          if (page.length < list.length)
            text += `\n${theme.fg("dim", `Page offset ${offset}, ${page.length}/${list.length} tasks; use list offset/limit for more`)}`;
          return new Text(boundedText(text), 0, 0);
        }
        case "add":
        case "update": {
          // Old snapshots have no affectedIds: retain their original output
          // rather than infer metadata from prose (which may contain newlines).
          if (
            !Array.isArray(data.affectedIds) ||
            !data.affectedIds.length ||
            data.affectedIds.length > MAX_BATCH ||
            !data.affectedIds.every(positiveId) ||
            new Set(data.affectedIds).size !== data.affectedIds.length
          )
            return fallback();
          const byId = new Map(list.map((task) => [task.id, task]));
          const affected = data.affectedIds.map((id) => byId.get(id));
          if (affected.some((task) => !task)) return fallback();
          const shown = expanded ? affected : affected.slice(0, 6);
          let text = shown.map((task) => renderTask(task!, theme)).join("\n");
          if (shown.length < affected.length)
            text += `\n${theme.fg("dim", `… ${affected.length - shown.length} more`)}`;
          return new Text(boundedText(text), 0, 0);
        }
        case "remove":
        case "clear":
          return fallback();
        default:
          return fallback();
      }
    },
  });
  pi.registerCommand("todos", {
    description: "Show the task list for the current branch",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/todos requires interactive mode", "error");
        return;
      }
      await ctx.ui.custom<void>((tui, theme, _kb, done) => {
        const component = new TodoListComponent(snapshot(), theme, () => done());
        return {
          render: (width: number) => component.render(width),
          invalidate: () => component.invalidate(),
          handleInput: (data: string) => {
            component.handleInput(data);
            tui.requestRender();
          },
        };
      });
    },
  });
}
