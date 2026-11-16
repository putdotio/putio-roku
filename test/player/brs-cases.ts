import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Writable } from "node:stream";
import { execute } from "@rokucommunity/brs";
import { repoRoot } from "../live-test/repo-files.ts";

function sink(): NodeJS.WriteStream {
  return new Writable({ write: (_chunk, _encoding, done) => done() }) as NodeJS.WriteStream;
}

function brsStringLiteral(value: string): string {
  return `"${value.replaceAll('"', '""')}"`;
}

export async function runBrsCases<Result>(
  sources: readonly string[],
  driver: string,
  cases: Record<string, unknown>,
): Promise<Record<string, Result>> {
  const casesDir = mkdtempSync(join(tmpdir(), "putio-roku-brs-cases-"));
  const casesFile = join(casesDir, "cases.brs");
  writeFileSync(
    casesFile,
    `function driverCases() as object\n    return ParseJson(${brsStringLiteral(JSON.stringify(cases))})\nend function\n`,
  );

  try {
    const [output] = await execute(
      [...sources.map((file) => join(repoRoot, file)), casesFile, join(repoRoot, driver)],
      { root: repoRoot, componentDirs: [], stdout: sink(), stderr: sink() },
    );
    return JSON.parse(String(output)) as Record<string, Result>;
  } finally {
    rmSync(casesDir, { recursive: true, force: true });
  }
}
