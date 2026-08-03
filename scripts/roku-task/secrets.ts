import {
  chmodSync,
  existsSync,
  lstatSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import process from "node:process";
import { repoRoot, requireEnv, run } from "./runtime.ts";

const secretKeys = [
  "AUDIO_CONTENT_ID",
  "IMAGE_CONTENT_ID",
  "PLAYBACK_CONTENT_ID",
  "PUTIO_CLI_CONFIG_PATH",
  "PUTIO_CLI_PROFILE",
  "PUTIO_CLIENT_ID_FIRST_PARTY",
  "PUTIO_CLIENT_SECRET_FIRST_PARTY",
  "PUTIO_TEST_PASSWORD",
  "PUTIO_TEST_TOTP_REFERENCE",
  "PUTIO_TEST_USERNAME",
  "ROKU_DEV_PASSWORD",
  "SUBTITLE_CONTENT_ID",
] as const;

const numericSecretKeys = new Set<string>([
  "AUDIO_CONTENT_ID",
  "IMAGE_CONTENT_ID",
  "PLAYBACK_CONTENT_ID",
  "PUTIO_CLIENT_ID_FIRST_PARTY",
  "SUBTITLE_CONTENT_ID",
]);

interface RokuSecretPayload {
  readonly AUDIO_CONTENT_ID: string;
  readonly IMAGE_CONTENT_ID: string;
  readonly PLAYBACK_CONTENT_ID: string;
  readonly PUTIO_CLI_CONFIG_PATH: string;
  readonly PUTIO_CLI_PROFILE: string;
  readonly PUTIO_CLIENT_ID_FIRST_PARTY: string;
  readonly PUTIO_CLIENT_SECRET_FIRST_PARTY: string;
  readonly PUTIO_TEST_PASSWORD: string;
  readonly PUTIO_TEST_TOTP_REFERENCE: string;
  readonly PUTIO_TEST_USERNAME: string;
  readonly ROKU_DEV_PASSWORD: string;
  readonly SUBTITLE_CONTENT_ID: string;
}

export function secretsSetup(): void {
  if (process.env.SECRETS_OUTPUT !== undefined) {
    throw new Error("SECRETS_OUTPUT is no longer supported; setup writes .env.local");
  }

  const ciphertext = requireEnv(
    "PUTIO_ROKU_SOPS_FILE",
    "PUTIO_ROKU_SOPS_FILE=/path/to/roku.sops.env pnpm roku secrets-setup",
  );
  const output = ".env.local";
  assertRegularFile(ciphertext, "ciphertext input");
  if (existsSync(output)) {
    assertRegularFile(output, "output");
  }

  const tempDir = mkdtempSync(join(tmpdir(), "putio-roku-secrets-"));
  chmodSync(tempDir, 0o700);
  const decryptedFile = join(tempDir, "payload.json");
  const renderedFile = join(tempDir, "env");
  try {
    decryptSopsPayload(ciphertext, decryptedFile);
    assertRegularFile(decryptedFile, "decrypted payload");
    chmodSync(decryptedFile, 0o600);
    const payload = parseSecretPayload(readFileSync(decryptedFile, "utf8"));
    writeFileSync(renderedFile, renderSecretPayload(payload), { flag: "wx", mode: 0o600 });
    installSecretFile(renderedFile, output);
  } finally {
    rmSync(tempDir, { force: true, recursive: true });
  }
}

function parseSecretPayload(serialized: string): RokuSecretPayload {
  let decoded: unknown;
  try {
    decoded = JSON.parse(serialized);
  } catch {
    throw new Error("Decrypted SOPS payload must be valid JSON");
  }

  if (typeof decoded !== "object" || decoded === null || Array.isArray(decoded)) {
    throw new Error("Decrypted SOPS payload must be a JSON object");
  }

  const values = new Map(Object.entries(decoded));
  const actualKeys = [...values.keys()].sort();
  const expectedKeys = [...secretKeys].sort();
  if (actualKeys.join("\n") !== expectedKeys.join("\n")) {
    throw new Error("Decrypted SOPS payload key inventory does not match the Roku contract");
  }

  return {
    AUDIO_CONTENT_ID: readSecret(values, "AUDIO_CONTENT_ID"),
    IMAGE_CONTENT_ID: readSecret(values, "IMAGE_CONTENT_ID"),
    PLAYBACK_CONTENT_ID: readSecret(values, "PLAYBACK_CONTENT_ID"),
    PUTIO_CLI_CONFIG_PATH: readSecret(values, "PUTIO_CLI_CONFIG_PATH"),
    PUTIO_CLI_PROFILE: readSecret(values, "PUTIO_CLI_PROFILE"),
    PUTIO_CLIENT_ID_FIRST_PARTY: readSecret(values, "PUTIO_CLIENT_ID_FIRST_PARTY"),
    PUTIO_CLIENT_SECRET_FIRST_PARTY: readSecret(values, "PUTIO_CLIENT_SECRET_FIRST_PARTY"),
    PUTIO_TEST_PASSWORD: readSecret(values, "PUTIO_TEST_PASSWORD"),
    PUTIO_TEST_TOTP_REFERENCE: readSecret(values, "PUTIO_TEST_TOTP_REFERENCE"),
    PUTIO_TEST_USERNAME: readSecret(values, "PUTIO_TEST_USERNAME"),
    ROKU_DEV_PASSWORD: readSecret(values, "ROKU_DEV_PASSWORD"),
    SUBTITLE_CONTENT_ID: readSecret(values, "SUBTITLE_CONTENT_ID"),
  };
}

function renderSecretPayload(payload: RokuSecretPayload): string {
  return `${secretKeys.map((key) => `${key}=${JSON.stringify(payload[key])}`).join("\n")}\n`;
}

export function secretsClean(): void {
  rmSync(".env.local", { force: true });
  for (const entry of readdirSync(repoRoot)) {
    if (/^\.env\.local\.(?:.+|swp)$/.test(entry)) {
      rmSync(entry, { force: true });
    }
  }
}

function readSecret(values: ReadonlyMap<string, unknown>, key: string): string {
  const value = values.get(key);
  if (typeof value !== "string") {
    throw new Error(`Decrypted SOPS payload value for ${key} must be a string`);
  }
  if (value === "") {
    throw new Error(`Decrypted SOPS payload value for ${key} must not be empty`);
  }
  if (/^["'].*["']$/.test(value)) {
    throw new Error(`Decrypted SOPS payload value for ${key} must not be quote-wrapped`);
  }
  if (/[\u0000-\u001f\u007f]/.test(value)) {
    throw new Error(`Decrypted SOPS payload value for ${key} must not contain control characters`);
  }
  if (numericSecretKeys.has(key) && !/^[0-9]+$/.test(value)) {
    throw new Error(`Decrypted SOPS payload value for ${key} must contain decimal digits only`);
  }
  return value;
}

function decryptSopsPayload(ciphertext: string, output: string): void {
  run("sops", [
    "decrypt",
    "--input-type",
    "dotenv",
    "--output-type",
    "json",
    "--output",
    output,
    ciphertext,
  ]);
}

function assertRegularFile(path: string, label: string): void {
  if (!existsSync(path)) {
    throw new Error(`${label} must be one regular non-symlink file: ${path}`);
  }

  const status = lstatSync(path);
  if (!status.isFile() || status.isSymbolicLink()) {
    throw new Error(`${label} must be one regular non-symlink file: ${path}`);
  }
}

function installSecretFile(source: string, output: string): void {
  const outputTempFile = join(
    dirname(output),
    `.${basename(output)}.${process.pid}.${Date.now()}.tmp`,
  );

  try {
    writeFileSync(outputTempFile, readFileSync(source), { flag: "wx", mode: 0o600 });
    chmodSync(outputTempFile, 0o600);
    renameSync(outputTempFile, output);
    chmodSync(output, 0o600);
  } catch (error) {
    rmSync(outputTempFile, { force: true });
    throw error;
  }
}
