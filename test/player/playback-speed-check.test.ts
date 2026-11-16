import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { expect, it } from "vitest";
import { repoRoot } from "../live-test/repo-files.ts";

function sink(): NodeJS.WriteStream {
  return new Writable({ write: (_chunk, _encoding, done) => done() }) as NodeJS.WriteStream;
}

it("reads the playing speed from the measured rate and drops the ignored ones", async () => {
  const files = [
    "components/screens/VideoPlayer/VideoPlayerSpeedCheck.brs",
    "test/player/playback-speed-check.brs",
  ].map((file) => join(repoRoot, file));
  const [output] = await execute(files, {
    root: repoRoot,
    componentDirs: [],
    stdout: sink(),
    stderr: sink(),
  });

  expect(JSON.parse(String(output))).toEqual({
    nearest: [2, 1, 4, 1.25, 0.5, 1],
    kept: [
      [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2],
      [0.25, 0.5, 0.75, 1],
      [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 3.5, 4],
    ],
  });
});
