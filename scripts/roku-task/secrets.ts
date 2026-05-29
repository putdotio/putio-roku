import {
  chmodSync,
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
import { envOr, repoRoot, requireEnv, run } from "./runtime.ts";

export function secretsSetup(): void {
  const projectId = requireEnv(
    "PUTIO_ROKU_INFISICAL_PROJECT_ID",
    "PUTIO_ROKU_INFISICAL_PROJECT_ID=<project-id> PUTIO_ROKU_INFISICAL_PATH=<path> pnpm roku secrets-setup",
  );
  const path = requireEnv(
    "PUTIO_ROKU_INFISICAL_PATH",
    "PUTIO_ROKU_INFISICAL_PROJECT_ID=<project-id> PUTIO_ROKU_INFISICAL_PATH=<path> pnpm roku secrets-setup",
  );
  const output = envOr("SECRETS_OUTPUT", ".env.local");
  const tempDir = mkdtempSync(join(tmpdir(), "putio-roku-secrets-"));
  chmodSync(tempDir, 0o700);
  const tempFile = join(tempDir, "env");
  try {
    run("infisical", [
      "export",
      "--silent",
      "--domain",
      envOr("PUTIO_INFISICAL_DOMAIN", "https://eu.infisical.com/api"),
      "--projectId",
      projectId,
      "--env",
      envOr("PUTIO_ROKU_INFISICAL_ENV", "dev"),
      "--path",
      path,
      "--format",
      "dotenv",
      "--output-file",
      tempFile,
    ]);
    installSecretFile(tempFile, output);
  } finally {
    rmSync(tempDir, { force: true, recursive: true });
  }
}

export function secretsClean(): void {
  rmSync(".env.local", { force: true });
  for (const entry of readdirSync(repoRoot)) {
    if (/^\.env\.local\.(?:.+|swp)$/.test(entry)) {
      rmSync(entry, { force: true });
    }
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
