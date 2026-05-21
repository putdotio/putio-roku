import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import {
  buildDebugCommand,
  runDebugCommand,
  type DebugCommandResult,
} from "@putdotio/rokit";
import { formatArtifactTimestamp } from "./artifacts.ts";
import { formatErrorMessage } from "./errors.ts";
import {
  captureDeveloperScreenshot,
  queryActiveApp,
  querySceneGraph,
  requireDeveloperPassword,
  rokitContext,
} from "./rokit-device.ts";

const debugCommandNames = [
  "chanperf",
  "free",
  "loaded_textures",
  "r2d2_bitmaps",
] as const;

export function defaultDebugArtifactDir(label = "debug"): string {
  return join(".local/roku-debug", `${label}-${formatArtifactTimestamp(new Date())}`);
}

export async function captureRokuDebugSnapshot(
  target: string,
  outputDir: string,
): Promise<void> {
  await mkdir(outputDir, { recursive: true });
  await writeText(join(outputDir, "active-app.json"), async () =>
    JSON.stringify(await queryActiveApp(target), null, 2),
  );
  await writeText(join(outputDir, "scenegraph.xml"), async () => await querySceneGraph(target));

  for (const commandName of debugCommandNames) {
    await writeText(join(outputDir, `${commandName}.json`), async () => {
      const result = await runDebugCommand(
        rokitContext(target, 5_000),
        buildDebugCommand(commandName, []),
        5_000,
        1_000,
      );

      return JSON.stringify(serializeDebugCommandResult(result), null, 2);
    });
  }

  await writeText(join(outputDir, "screenshot.path"), async () => {
    const password = requireDeveloperPassword();
    const screenshotPath = await captureDeveloperScreenshot(
      target,
      password,
      join(outputDir, "screenshot.jpg"),
    );

    return `${screenshotPath}\n`;
  });
}

async function writeText(path: string, read: () => Promise<string>): Promise<void> {
  try {
    await writeFile(path, await read());
  } catch (error) {
    await writeFile(
      `${path}.error`,
      `${formatErrorMessage(error)}\n`,
    );
  }
}

function serializeDebugCommandResult(result: DebugCommandResult): object {
  return {
    args: result.args,
    body: result.body,
    bytes: result.bytes,
    command: result.command,
    elapsedMs: result.elapsedMs,
    port: result.port,
  };
}
