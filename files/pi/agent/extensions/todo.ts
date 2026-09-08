/**
 * Task list for the agent, kept inside the session.
 *
 * Adapted from pi's bundled examples/extensions/todo.ts (MIT). State lives in
 * the `todo` tool's result details, never in a file: it is replayed from the
 * session branch on start and after branch switches, so it is always correct
 * for the point in history being viewed. A persistent widget above the editor
 * mirrors the current list; `/todos` opens the full list.
 */

import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { matchesKey, Text, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
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

interface TodoDetails {
  action: Action;
  tasks: Task[];
  nextId: number;
  error?: string;
}

const TodoParams = Type.Object({
  action: StringEnum(ACTIONS),
  text: Type.Optional(
    Type.String({ description: "Task text: the task to add, or the new text on update" }),
  ),
  items: Type.Optional(Type.Array(Type.String(), { description: "Several tasks to add at once" })),
  id: Type.Optional(Type.Number({ description: "Task id, for update and remove" })),
  status: Type.Optional(StringEnum(STATUSES)),
});

const WIDGET_KEY = "todo";
// The widget sits above the editor, so keep it short: when the list grows
// past this, finished tasks are the first to drop out of the widget (they
// stay in /todos and in the tool output).
const WIDGET_MAX_TASKS = 10;

function isDone(task: Task): boolean {
  return task.status === "done";
}

function progress(tasks: Task[]): string {
  return `${tasks.filter(isDone).length}/${tasks.length}`;
}

// One task as a line: checkbox, dim id, text styled by status.
function renderTask(task: Task, th: Theme): string {
  const id = th.fg("dim", `#${task.id}`);
  switch (task.status) {
    case "done":
      return `${th.fg("success", "☑")} ${id} ${th.fg("dim", th.strikethrough(task.text))}`;
    case "in_progress":
      return `${th.fg("accent", "▣")} ${id} ${th.fg("text", th.bold(task.text))}`;
    default:
      return `${th.fg("muted", "☐")} ${id} ${th.fg("text", task.text)}`;
  }
}

// Plain-text form for the model (tool output).
function describeTask(task: Task): string {
  const box = task.status === "done" ? "[x]" : task.status === "in_progress" ? "[~]" : "[ ]";
  return `${box} #${task.id} ${task.text}`;
}

function header(title: string, tasks: Task[], th: Theme, width: number): string {
  const label = th.fg("accent", th.bold(` ${title} `)) + th.fg("muted", `${progress(tasks)} `);
  const lead = th.fg("borderMuted", "──");
  const fill = Math.max(0, width - visibleWidth(lead) - visibleWidth(label));
  return truncateToWidth(lead + label + th.fg("borderMuted", "─".repeat(fill)), width);
}

function widgetLines(tasks: Task[], th: Theme, width: number): string[] {
  let shown = tasks;
  if (tasks.length > WIDGET_MAX_TASKS) {
    shown = tasks.filter((t) => !isDone(t));
    if (shown.length > WIDGET_MAX_TASKS) shown = shown.slice(0, WIDGET_MAX_TASKS);
  }
  const lines = [header("Tasks", tasks, th, width)];
  for (const task of shown) lines.push(truncateToWidth(`  ${renderTask(task, th)}`, width));
  const hidden = tasks.length - shown.length;
  if (hidden > 0) lines.push(truncateToWidth(`  ${th.fg("dim", `… ${hidden} more`)}`, width));
  return lines;
}

// Full list for the /todos command; Escape closes it.
class TodoListComponent {
  private cachedWidth?: number;
  private cachedLines?: string[];

  constructor(
    private tasks: Task[],
    private theme: Theme,
    private onClose: () => void,
  ) {}

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "q")) {
      this.onClose();
    }
  }

  render(width: number): string[] {
    if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;
    const th = this.theme;
    const lines: string[] = ["", header("Tasks", this.tasks, th, width), ""];
    if (this.tasks.length === 0) {
      lines.push(
        truncateToWidth(`  ${th.fg("dim", "No tasks yet. Ask the agent to plan some.")}`, width),
      );
    } else {
      for (const task of this.tasks)
        lines.push(truncateToWidth(`  ${renderTask(task, th)}`, width));
    }
    lines.push("", truncateToWidth(`  ${th.fg("dim", "Press Escape to close")}`, width), "");
    this.cachedWidth = width;
    this.cachedLines = lines;
    return lines;
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
}

export default function (pi: ExtensionAPI) {
  // In-memory state, reconstructed from the session on load.
  let tasks: Task[] = [];
  let nextId = 1;

  const snapshot = (): Task[] => tasks.map((t) => ({ ...t }));

  const refreshWidget = (ctx: ExtensionContext) => {
    if (!ctx.hasUI) return;
    if (tasks.length === 0) {
      ctx.ui.setWidget(WIDGET_KEY, undefined);
      return;
    }
    const shown = snapshot();
    ctx.ui.setWidget(WIDGET_KEY, (_tui, theme) => ({
      render: (width: number) => widgetLines(shown, theme, width),
      invalidate: () => {},
    }));
  };

  // Replay the branch: the latest `todo` tool result carries the whole list.
  const reconstructState = (ctx: ExtensionContext) => {
    tasks = [];
    nextId = 1;
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message") continue;
      const msg = entry.message;
      if (msg.role !== "toolResult" || msg.toolName !== "todo") continue;
      const details = msg.details as TodoDetails | undefined;
      if (details?.tasks) {
        tasks = details.tasks.map((t) => ({ ...t }));
        nextId = details.nextId;
      }
    }
    refreshWidget(ctx);
  };

  pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
  pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));

  const result = (action: Action, text: string, error?: string) => ({
    content: [{ type: "text" as const, text }],
    details: { action, tasks: snapshot(), nextId, ...(error ? { error } : {}) } as TodoDetails,
  });

  pi.registerTool({
    name: "todo",
    label: "Todo",
    description:
      "Task list for the current session, shown to the user. Actions: list; add (text, or items for " +
      "several); update (id, with status pending|in_progress|done and/or new text); remove (id); clear.",
    promptSnippet: "Plan and track multi-step work as a task list the user can see",
    promptGuidelines: [
      "Use todo to record the steps of any multi-step task before starting, mark each step " +
        "in_progress when you begin it and done when it is finished, and keep the list current " +
        "instead of restating the plan in prose.",
    ],
    parameters: TodoParams,

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const finish = (action: Action, text: string, error?: string) => {
        refreshWidget(ctx);
        return result(action, text, error);
      };

      switch (params.action) {
        case "list":
          return result("list", tasks.length ? tasks.map(describeTask).join("\n") : "No tasks");

        case "add": {
          const texts = (params.items ?? []).concat(params.text ? [params.text] : []);
          const cleaned = texts.map((t) => t.trim()).filter((t) => t.length > 0);
          if (cleaned.length === 0)
            return result("add", "Error: text or items required", "text required");
          const added: Task[] = cleaned.map((text) => ({ id: nextId++, text, status: "pending" }));
          tasks.push(...added);
          return finish("add", added.map((t) => `Added #${t.id}: ${t.text}`).join("\n"));
        }

        case "update": {
          if (params.id === undefined) return result("update", "Error: id required", "id required");
          const task = tasks.find((t) => t.id === params.id);
          if (!task)
            return result("update", `Task #${params.id} not found`, `#${params.id} not found`);
          if (params.status === undefined && !params.text) {
            return result("update", "Error: status or text required", "status or text required");
          }
          if (params.status !== undefined) task.status = params.status;
          if (params.text) task.text = params.text.trim();
          return finish("update", describeTask(task));
        }

        case "remove": {
          if (params.id === undefined) return result("remove", "Error: id required", "id required");
          const index = tasks.findIndex((t) => t.id === params.id);
          if (index < 0)
            return result("remove", `Task #${params.id} not found`, `#${params.id} not found`);
          const [removed] = tasks.splice(index, 1);
          return finish("remove", `Removed #${removed.id}: ${removed.text}`);
        }

        case "clear": {
          const count = tasks.length;
          tasks = [];
          nextId = 1;
          return finish("clear", `Cleared ${count} task(s)`);
        }

        default:
          return result(
            "list",
            `Unknown action: ${params.action}`,
            `unknown action: ${params.action}`,
          );
      }
    },

    renderCall(args, theme) {
      let text = theme.fg("toolTitle", theme.bold("todo ")) + theme.fg("muted", args.action);
      if (args.id !== undefined) text += ` ${theme.fg("accent", `#${args.id}`)}`;
      if (args.status) text += ` ${theme.fg("muted", args.status)}`;
      if (args.text) text += ` ${theme.fg("dim", `"${args.text}"`)}`;
      if (args.items?.length) text += ` ${theme.fg("dim", `${args.items.length} items`)}`;
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded }, theme) {
      const details = result.details as TodoDetails | undefined;
      if (!details) {
        const first = result.content[0];
        return new Text(first?.type === "text" ? first.text : "", 0, 0);
      }
      if (details.error) return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);

      const list = details.tasks;
      switch (details.action) {
        case "list": {
          if (list.length === 0) return new Text(theme.fg("dim", "No tasks"), 0, 0);
          const shown = expanded ? list : list.slice(0, 6);
          let text = theme.fg("muted", `${progress(list)} done`);
          for (const task of shown) text += `\n${renderTask(task, theme)}`;
          if (shown.length < list.length) {
            text += `\n${theme.fg("dim", `… ${list.length - shown.length} more`)}`;
          }
          return new Text(text, 0, 0);
        }
        case "add": {
          const first = result.content[0];
          const count = first?.type === "text" ? first.text.split("\n").length : 0;
          const added = list.slice(Math.max(0, list.length - count));
          return new Text(added.map((task) => renderTask(task, theme)).join("\n"), 0, 0);
        }
        case "update": {
          const first = result.content[0];
          const id = first?.type === "text" ? Number(/#(\d+)/.exec(first.text)?.[1]) : Number.NaN;
          const task = list.find((t) => t.id === id);
          return new Text(task ? renderTask(task, theme) : theme.fg("muted", "Updated"), 0, 0);
        }
        case "remove":
        case "clear": {
          const first = result.content[0];
          const msg = first?.type === "text" ? first.text : "";
          return new Text(theme.fg("muted", msg), 0, 0);
        }
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
      await ctx.ui.custom<void>((_tui, theme, _kb, done) => {
        return new TodoListComponent(snapshot(), theme, () => done());
      });
    },
  });
}
