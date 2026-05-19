#!/usr/bin/env node
import { spawn } from "node:child_process";
import process from "node:process";

const manifestPath = "docs/visual/manifest.json";
const outputPath = "docs/visual/index.html";

await runVref(["build", "--manifest", manifestPath, "--out", outputPath]);

function runVref(args: string[]): Promise<void> {
  const vrefBin = process.env.VREF_BIN ?? "vref";

  return new Promise((resolve, reject) => {
    const child = spawn(vrefBin, args, {
      stdio: "inherit",
      shell: process.platform === "win32",
    });

    child.on("error", (error) => {
      reject(
        new Error(
          `Failed to run ${vrefBin}. Install @putdotio/vref or set VREF_BIN to a built vref CLI: ${error.message}`,
        ),
      );
    });

    child.on("exit", (code, signal) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${vrefBin} ${args.join(" ")} failed with ${signal ?? `exit code ${code}`}`));
    });
  });
}
