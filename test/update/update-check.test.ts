import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { expect, it } from "vitest";
import { repoRoot } from "../live-test/repo-files.ts";

function sink(): NodeJS.WriteStream {
  return new Writable({ write: (_chunk, _encoding, done) => done() }) as NodeJS.WriteStream;
}

it("offers each newer build once and reads dev installer outcomes", async () => {
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
    packageUrl: "https://roku.put.io/releases/v2/2.21.0.zip",
    challenge: [{ realm: "rokudev", nonce: "1794847765", qop: "auth" }, null, null],
    digestResponse: [
      "h(h(rokudev:rokudev:pw):n1:00000001:c1:auth:h(POST:/plugin_install))",
      "h(h(rokudev:rokudev:pw):n1:h(POST:/plugin_install))",
    ],
    authorization:
      "Digest username='rokudev', realm='rokudev', nonce='n1', uri='/plugin_install', response='r1', qop=auth, nc=00000001, cnonce='c1'",
    zip: [true, false, false],
    installer: ["installed", "badPassword", "failed", "failed"],
    body: [
      "--b",
      "Content-Disposition: form-data; name='mysubmit'",
      "",
      "Install",
      "--b",
      "Content-Disposition: form-data; name='archive'; filename='putio.zip'",
      "Content-Type: application/zip",
      "",
      "ZIP",
      "--b--",
      "",
    ],
  });
});
