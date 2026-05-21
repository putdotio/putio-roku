#!/usr/bin/env node
import { execFile as execFileCallback } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import process from "node:process";
import { promisify } from "node:util";

const execFile = promisify(execFileCallback);

const defaultAccount = "putdotio.1password.com";
const defaultVault = "frontend-dev";
const defaultItem = "putio-roku";
const defaultOutputPath = ".env.local";

const generatedKeys = [
  "PUTIO_CLI_PROFILE",
  "PUTIO_CLI_CONFIG_PATH",
  "PUTIO_HARNESS_ACCOUNT_ITEM",
  "PUTIO_HARNESS_ACCOUNT_VAULT",
  "PUTIO_HARNESS_OAUTH_ITEM",
  "PUTIO_HARNESS_OAUTH_VAULT",
  "PLAYBACK_CONTENT_ID",
  "IMAGE_CONTENT_ID",
  "AUDIO_CONTENT_ID",
  "SUBTITLE_CONTENT_ID",
] as const;

const localOnlyKeys = [
  "ROKU_DEV_TARGET",
  "ROKU_DEV_PASSWORD",
  "ROKIT_TARGET",
  "ROKIT_PASSWORD",
  "PLAYER_UI_REFERENCE_IMAGE",
  "ROKU_DEBUG_ARTIFACT_DIR",
] as const;

type EnvKey = typeof generatedKeys[number];
type LocalKey = typeof localOnlyKeys[number];

type OpField = {
  label: string;
  value: string;
  sectionLabel: string | null;
};

function usage(): never {
  console.error(`usage:
  node scripts/render-env-local.ts [output-path]

environment:
  PUTIO_ROKU_1PASSWORD_ACCOUNT=putdotio.1password.com
  PUTIO_ROKU_1PASSWORD_VAULT=frontend-dev
  PUTIO_ROKU_ENV_ITEM=putio-roku`);
  process.exit(1);
}

function stringField(record: Record<string, unknown>, key: string): string | undefined {
  const value = record[key];
  return typeof value === "string" ? value : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return isRecord(value) ? value : undefined;
}

function objectField(record: Record<string, unknown>, key: string): Record<string, unknown> | undefined {
  return asRecord(record[key]);
}

function normalizeLabel(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]/g, "");
}

function shellQuote(value: string): string {
  return `"${value.replace(/(["\\$`])/g, "\\$1")}"`;
}

function parseSimpleEnv(text: string): Map<string, string> {
  const values = new Map<string, string>();

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#")) {
      continue;
    }

    const match = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line);
    if (match === null) {
      continue;
    }

    const key = match[1];
    const rawValue = match[2];
    if (key === undefined || rawValue === undefined) {
      continue;
    }

    const trimmedValue = rawValue.trim();
    const value =
      trimmedValue.startsWith("\"") && trimmedValue.endsWith("\"")
        ? trimmedValue.slice(1, -1).replace(/\\"/g, "\"").replace(/\\\\/g, "\\")
        : trimmedValue;
    values.set(key, value);
  }

  return values;
}

async function readExistingEnv(path: string): Promise<Map<string, string>> {
  try {
    return parseSimpleEnv(await readFile(path, "utf8"));
  } catch (error) {
    const errorRecord = asRecord(error);
    const code = errorRecord === undefined ? undefined : errorRecord.code;
    if (code === "ENOENT") {
      return new Map();
    }

    throw error;
  }
}

function parseOpFields(value: unknown): ReadonlyArray<OpField> {
  const record = asRecord(value);
  if (record === undefined) {
    throw new Error("1Password item response was not an object");
  }

  const fieldsValue = record.fields;
  if (!Array.isArray(fieldsValue)) {
    throw new Error("1Password item response did not contain a fields array");
  }

  return fieldsValue.flatMap((fieldValue) => {
    const fieldRecord = asRecord(fieldValue);
    if (fieldRecord === undefined) {
      return [];
    }

    const label = stringField(fieldRecord, "label");
    const valueText = stringField(fieldRecord, "value");
    if (label === undefined || valueText === undefined || valueText === "") {
      return [];
    }

    const sectionRecord = objectField(fieldRecord, "section");
    const sectionLabel = sectionRecord === undefined ? null : stringField(sectionRecord, "label") ?? null;
    return [{ label, value: valueText, sectionLabel }];
  });
}

async function readOnePasswordFields(input: {
  account: string;
  item: string;
  vault: string;
}): Promise<ReadonlyArray<OpField>> {
  const args = [
    "item",
    "get",
    input.item,
    "--account",
    input.account,
    "--vault",
    input.vault,
    "--format",
    "json",
  ];

  try {
    const { stdout } = await execFile("op", args, { maxBuffer: 1024 * 1024 });
    return parseOpFields(JSON.parse(stdout));
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(
      `Could not read 1Password item "${input.item}" from vault "${input.vault}". Run "op signin --account ${input.account}" and make sure you have access. ${message}`,
    );
  }
}

function valueFor(fields: ReadonlyArray<OpField>, key: EnvKey): string {
  const normalizedKey = normalizeLabel(key);

  for (const field of fields) {
    const candidates = [
      field.label,
      field.sectionLabel === null ? field.label : `${field.sectionLabel}.${field.label}`,
    ];

    if (candidates.some((candidate) => normalizeLabel(candidate) === normalizedKey)) {
      return field.value;
    }
  }

  throw new Error(`1Password item is missing Roku field "${key}"`);
}

function renderEnv(input: {
  generatedValues: ReadonlyMap<EnvKey, string>;
  preservedValues: ReadonlyMap<string, string>;
  source: string;
}): string {
  const lines = [
    "# Generated by `make secrets-setup` from the put.io 1Password testing account.",
    "# Edit Roku device values below locally; do not commit this file.",
    `# Source: ${input.source}`,
    "",
  ];

  for (const key of generatedKeys) {
    const value = input.generatedValues.get(key);
    if (value === undefined) {
      throw new Error(`Generated value missing for ${key}`);
    }

    lines.push(`${key}=${shellQuote(value)}`);
  }

  lines.push("", "# Local Roku device overrides.");
  for (const key of localOnlyKeys) {
    const value = input.preservedValues.get(key);
    lines.push(`${key}=${shellQuote(value ?? "")}`);
  }

  lines.push("");
  return lines.join("\n");
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.includes("--help") || args.includes("-h")) {
    usage();
  }

  if (args.length > 1) {
    usage();
  }

  const outputPath = args[0] ?? process.env.PUTIO_ROKU_ENV_OUTPUT?.trim() ?? defaultOutputPath;
  const account = process.env.PUTIO_ROKU_1PASSWORD_ACCOUNT?.trim() || defaultAccount;
  const vault = process.env.PUTIO_ROKU_1PASSWORD_VAULT?.trim() || defaultVault;
  const item = process.env.PUTIO_ROKU_ENV_ITEM?.trim() || defaultItem;
  const fields = await readOnePasswordFields({ account, item, vault });
  const generatedValues = new Map<EnvKey, string>();

  for (const key of generatedKeys) {
    generatedValues.set(key, valueFor(fields, key));
  }

  const existingValues = await readExistingEnv(outputPath);
  const fallbackValues = await readExistingEnv(".env");
  const preservedValues = new Map<LocalKey, string>();

  for (const key of localOnlyKeys) {
    const value = existingValues.get(key) ?? fallbackValues.get(key);
    if (value !== undefined) {
      preservedValues.set(key, value);
    }
  }

  await writeFile(
    outputPath,
    renderEnv({
      generatedValues,
      preservedValues,
      source: `${account}/${vault}/${item}`,
    }),
    { mode: 0o600 },
  );

  console.log(`Rendered ${outputPath} from 1Password item ${item}.`);
}

await main();
