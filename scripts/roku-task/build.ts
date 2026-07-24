import { copyFileSync, existsSync, readdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";
import { generateRokuAssets } from "../generate-roku-assets.ts";
import { generateRokuDesign } from "../generate-roku-design.ts";
import { generateRokuIcons } from "../generate-roku-icons.ts";
import { packageRokuApp } from "../package-roku.ts";
import {
  appZipFile,
  artifactName,
  assertFile,
  repoRoot,
  run,
  runPnpm,
  selectedVariantConfig,
  tmpDir,
  withEnv,
  zipDir,
  type VariantConfig,
} from "./runtime.ts";

export async function packageRoku(config: VariantConfig): Promise<void> {
  const outFile = appZipFile(config);
  const result = await packageRokuApp({
    appTitle: process.env.ROKU_APP_TITLE ?? config.title,
    outFile,
    putioAppId: process.env.PUTIO_ROKU_APP_ID,
    repoRoot,
    variant: config.variant,
  });
  assertFile(outFile);
  console.log(`Packaged ${result.title} (${result.variant}) with ${result.fileCount} source files: ${result.outFile}`);
}

export function clean(): void {
  rmSync("build", { force: true, recursive: true });
  rmSync(tmpDir, { force: true, recursive: true });
  if (existsSync(zipDir)) {
    for (const entry of readdirSync(zipDir)) {
      if (entry.endsWith(".zip")) {
        rmSync(join(zipDir, entry), { force: true });
      }
    }
  }
}

export function checkRokuStatic(): void {
  console.log("*** Running Roku static checks ***");
  runPnpm(["exec", "bslint", "--project", "bsconfig.json"]);
}

export function checkRokuFormat(): void {
  runPnpm(["exec", "bsfmt", "source/**/*.{brs,bs}", "components/**/*.{brs,bs}", "--check"]);
}

export function checkRokuLive(): void {
  runPnpm(["exec", "tsc", "-p", "tsconfig.live.json"]);
}

export function testLive(): void {
  runPnpm(["exec", "vitest", "run"]);
}

export async function checkRokuDesign(): Promise<void> {
  const outputPath = "source/DesignTokens.brs";
  await generateRokuDesign(repoRoot);
  assertFile(outputPath);
  run("git", ["diff", "--exit-code", "--", outputPath]);
}

export async function checkRokuAssets(): Promise<void> {
  await generateRokuAssets(repoRoot);
  for (const variant of ["production", "development", "lab"]) {
    for (const fileName of [
      "channel-poster_fhd.png",
      "channel-poster_hd.png",
      "channel-poster_sd.png",
      "Splash-FHD.png",
      "Splash-HD.png",
      "Splash-SD.png",
    ]) {
      assertFile(`images/generated/${variant}/${fileName}`);
    }
  }
  run("git", ["diff", "--exit-code", "--", "images/generated"]);
}

export async function icons(): Promise<void> {
  const outputs = await generateRokuIcons(repoRoot);
  console.log(`Generated ${outputs.length} Roku icon assets from config/phosphor-icons.json`);
}

export async function checkRokuIcons(): Promise<void> {
  const outputs = await generateRokuIcons(repoRoot);
  for (const outputPath of outputs) {
    assertFile(outputPath);
  }
  assertFile("third-party/phosphor-icons/LICENSE");
  run("git", ["diff", "--exit-code", "--", "images/icons", "third-party/phosphor-icons"]);
}

export async function verify(): Promise<void> {
  clean();
  checkRokuLive();
  await checkRokuDesign();
  await checkRokuAssets();
  await checkRokuIcons();
  testLive();
  checkRokuFormat();
  checkRokuStatic();
  visualValidate();
  await packageRoku(selectedVariantConfig());
}

export async function artifact(): Promise<void> {
  await withEnv(
    {
      PUTIO_ROKU_APP_ID: "3776",
      ROKU_APP_TITLE: "put.io",
      ROKU_VARIANT: "production",
    },
    verify,
  );
  const sourceZip = join(zipDir, "put.io.zip");
  const artifactZip = join(zipDir, artifactName);
  assertFile(sourceZip);
  rmSync(artifactZip, { force: true });
  copyFileSync(sourceZip, artifactZip);
  rmSync(sourceZip, { force: true });
  assertFile(artifactZip);
}

export function visualGallery(): void {
  run("node", ["scripts/vref.ts", "build", "--output", "json"]);
}

export function visualValidate(): void {
  run("node", ["scripts/vref.ts", "validate", "--output", "json"]);
}
