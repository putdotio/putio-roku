import { join } from "node:path";

export function defaultPlayerUiOutputDir(): string {
  return join("dist/tmp/player-ui", formatArtifactTimestamp(new Date()));
}

export function defaultFlowOutputDir(flowName: string): string {
  return join("dist/tmp/flows", `${flowName}-${formatArtifactTimestamp(new Date())}`);
}

export function defaultVisualPagesOutputDir(): string {
  return join("dist/tmp/visual/pages", formatArtifactTimestamp(new Date()));
}

export function defaultVisualLabOutputDir(): string {
  return join("dist/tmp/visual/lab", formatArtifactTimestamp(new Date()));
}

export function formatArtifactTimestamp(date: Date): string {
  return [
    date.getFullYear().toString(),
    padDatePart(date.getMonth() + 1),
    padDatePart(date.getDate()),
    "-",
    padDatePart(date.getHours()),
    padDatePart(date.getMinutes()),
    padDatePart(date.getSeconds()),
    "-",
    padDatePart(date.getMilliseconds(), 3),
  ].join("");
}

function padDatePart(value: number, width = 2): string {
  return value.toString().padStart(width, "0");
}
