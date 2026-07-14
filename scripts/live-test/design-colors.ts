import { readFileSync } from "node:fs";
import { join } from "node:path";

const designTokenSource = readFileSync(join(process.cwd(), "source/DesignTokens.brs"), "utf8");

export function rokuDesignColor(name: string): string {
  const match = new RegExp(`^\\s*${escapeRegExp(name)}:\\s*"([^"]+)"`, "m").exec(designTokenSource);
  if (match === null || match[1] === undefined) {
    throw new Error(`Missing generated Roku design token: ${name}`);
  }

  return match[1];
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
