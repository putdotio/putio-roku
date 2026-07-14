import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { resolveSecretExportFile } from "../../scripts/roku-task/secrets.ts";

const tempDirs: string[] = [];

afterEach(() => {
  for (const tempDir of tempDirs.splice(0)) {
    rmSync(tempDir, { force: true, recursive: true });
  }
});

describe("Infisical export output", () => {
  it("accepts the requested output path", () => {
    const requestedPath = makeRequestedPath();
    writeFileSync(requestedPath, "EXAMPLE=value\n");

    expect(resolveSecretExportFile(requestedPath)).toBe(requestedPath);
  });

  it("accepts the dotenv suffix added by Infisical", () => {
    const requestedPath = makeRequestedPath();
    writeFileSync(`${requestedPath}.env`, "EXAMPLE=value\n");

    expect(resolveSecretExportFile(requestedPath)).toBe(`${requestedPath}.env`);
  });

  it("rejects missing or ambiguous export output", () => {
    const requestedPath = makeRequestedPath();
    expect(() => resolveSecretExportFile(requestedPath)).toThrow(
      "Infisical export wrote 0 recognized output files",
    );

    writeFileSync(requestedPath, "FIRST=value\n");
    writeFileSync(`${requestedPath}.env`, "SECOND=value\n");
    expect(() => resolveSecretExportFile(requestedPath)).toThrow(
      "Infisical export wrote 2 recognized output files",
    );
  });
});

function makeRequestedPath(): string {
  const tempDir = mkdtempSync(join(tmpdir(), "putio-roku-secrets-test-"));
  tempDirs.push(tempDir);
  return join(tempDir, "env");
}
