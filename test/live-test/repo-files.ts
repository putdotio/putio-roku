import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

export const repoRoot = fileURLToPath(new URL("../..", import.meta.url));

export function readRepoFile(path: string): string {
  return readFileSync(join(repoRoot, path), "utf8");
}

export function listRepoFiles(directory: string, suffix?: string): readonly string[] {
  const files: string[] = [];

  for (const entry of readdirSync(directory)) {
    const absolutePath = join(directory, entry);
    const stat = statSync(absolutePath);

    if (stat.isDirectory()) {
      files.push(...listRepoFiles(absolutePath, suffix));
    } else if (suffix === undefined || entry.endsWith(suffix)) {
      files.push(relative(repoRoot, absolutePath));
    }
  }

  return files;
}
