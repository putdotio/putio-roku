import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { expect, it } from "vitest";
import { repoRoot } from "../live-test/repo-files.ts";

function sink(): NodeJS.WriteStream {
  return new Writable({ write: (_chunk, _encoding, done) => done() }) as NodeJS.WriteStream;
}

it("offers each newer sideload build once and ignores unreadable manifests", async () => {
  const files = [
    "components/shared/UpdateCheck/UpdateCheck.brs",
    "test/update/update-check.brs",
  ].map((file) => join(repoRoot, file));
  const [output] = await execute(files, {
    root: repoRoot,
    componentDirs: [],
    stdout: sink(),
    stderr: sink(),
  });

  expect(JSON.parse(String(output))).toEqual({
    newer: [true, true, true, false, false, false, false, false],
    manifest: ["2.19.0", "", "", ""],
    offer: [true, false, true, false],
    description: ["2.18.00004  |  2.19.0 available", "2.18.00004"],
  });
});
