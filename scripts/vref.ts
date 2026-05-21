import process from "node:process";
import {
  buildGallery,
  validateGallery,
} from "@putdotio/vref";

type VrefCommand = "build" | "validate";

const defaultManifestPath = ".vref/manifest.json";
const defaultOutputPath = ".vref/index.html";

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);

  if (command !== "build" && command !== "validate") {
    usage();
  }

  const manifestPath = getStringFlag(args, "manifest") ?? defaultManifestPath;
  const output = getOutputMode(args);

  if (command === "validate" || hasBooleanFlag(args, "check") || hasBooleanFlag(args, "dry-run")) {
    const result = await validateGallery({
      cwd: process.cwd(),
      manifestPath,
    });
    print(output, result, `validated ${result.screenshotCount} references`);
    return;
  }

  const result = await buildGallery({
    cwd: process.cwd(),
    manifestPath,
    outputPath: getStringFlag(args, "out") ?? getStringFlag(args, "output-path") ?? defaultOutputPath,
  });
  print(output, result, `wrote ${result.outputPath}`);
}

function getStringFlag(args: readonly string[], name: string): string | undefined {
  const prefixedName = `--${name}=`;
  const inline = args.find((arg) => arg.startsWith(prefixedName));
  if (inline !== undefined) {
    return inline.slice(prefixedName.length);
  }

  const index = args.indexOf(`--${name}`);
  if (index >= 0) {
    return args[index + 1];
  }

  return undefined;
}

function hasBooleanFlag(args: readonly string[], name: string): boolean {
  return args.includes(`--${name}`);
}

function getOutputMode(args: readonly string[]): "human" | "json" {
  return getStringFlag(args, "output") === "json" ? "json" : "human";
}

function print(output: "human" | "json", result: unknown, human: string): void {
  if (output === "json") {
    console.log(JSON.stringify({ ok: true, result }, null, 2));
    return;
  }

  console.log(human);
}

function usage(): never {
  console.error(`usage:
  node scripts/vref.ts build [--manifest .vref/manifest.json] [--out .vref/index.html] [--check] [--output json]
  node scripts/vref.ts validate [--manifest .vref/manifest.json] [--output json]`);
  process.exit(1);
}

await main();
