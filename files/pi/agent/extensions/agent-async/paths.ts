import { realpathSync } from "node:fs";
import { dirname, isAbsolute, relative, resolve } from "node:path";

export function canonical(path: string): string {
  try {
    return realpathSync(path);
  } catch (error: any) {
    if (error.code !== "ENOENT") throw error;
    const parent = dirname(path);
    if (parent === path) throw error;
    return resolve(canonical(parent), relative(parent, path));
  }
}
export function scopedPath(root: string, input: string): string {
  const base = realpathSync(root);
  const path = canonical(resolve(base, input.replace(/^@/, "")));
  const rel = relative(base, path);
  if (isAbsolute(rel) || rel === ".." || rel.startsWith("../"))
    throw new Error("Path is outside the assigned workspace.");
  return path;
}
export function writablePath(root: string, input: string): string {
  const path = scopedPath(root, input);
  const rel = relative(realpathSync(root), path);
  if (
    !rel ||
    rel.split(/[\\/]/).some((p) => [".git", ".pi", ".agents"].includes(p)) ||
    /(^|\/)(AGENTS(?:\.override)?\.md|CLAUDE\.md|\.env(?:\..*)?)$/.test(rel)
  ) {
    throw new Error("Agent writes to instruction, credential, or control paths are prohibited.");
  }
  return path;
}
