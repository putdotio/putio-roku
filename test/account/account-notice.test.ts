import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { expect, it } from "vitest";
import { repoRoot } from "../live-test/repo-files.ts";

function sink(): NodeJS.WriteStream {
  return new Writable({ write: (_chunk, _encoding, done) => done() }) as NodeJS.WriteStream;
}

const deactivated = "Your account has been deactivated";

it("shows the canonical inactive-account notice and nothing for active accounts", async () => {
  const files = ["components/shared/AccountStatus.brs", "test/account/account-notice.brs"].map(
    (file) => join(repoRoot, file),
  );
  const [output] = await execute(files, {
    root: repoRoot,
    componentDirs: [],
    stdout: sink(),
    stderr: sink(),
  });

  expect(JSON.parse(String(output))).toEqual({
    active: null,
    legacyActive: null,
    noUser: null,
    ownerWithDate: {
      title: deactivated,
      message: "Your files are still here, but they are scheduled to be deleted in 14 days.",
    },
    ownerTomorrow: {
      title: deactivated,
      message: "Your files are still here, but they are scheduled to be deleted in 1 day.",
    },
    ownerPastDate: {
      title: deactivated,
      message: "Your files are still here, but they are scheduled to be deleted in 0 days.",
    },
    ownerNoDate: { title: deactivated, message: "" },
    legacyInactive: { title: deactivated, message: "" },
    familyMember: { title: "Your family plan is no longer active.", message: "" },
  });
});
