import { existsSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  defaultTitleForVariant,
  packageRokuApp,
  parseVariant,
  renderBuildConfig,
  renderVariantManifest,
} from "../../scripts/package-roku.ts";

const repoRoot = process.cwd();
const packageTestDir = "dist/tmp/package-tests";

describe("Roku package variants", () => {
  it("keeps Lab files out of production and development packages", async () => {
    rmSync(join(repoRoot, packageTestDir), { recursive: true, force: true });

    const production = await packageRokuApp({
      outFile: `${packageTestDir}/put.io-test.zip`,
      repoRoot,
      variant: "production",
    });
    const development = await packageRokuApp({
      outFile: `${packageTestDir}/put.io-dev-test.zip`,
      repoRoot,
      variant: "development",
    });
    const lab = await packageRokuApp({
      outFile: `${packageTestDir}/put.io-lab-test.zip`,
      repoRoot,
      variant: "lab",
    });

    expect(production.files.some((file) => file.startsWith("components/lab/"))).toBe(false);
    expect(development.files.some((file) => file.startsWith("components/lab/"))).toBe(false);
    expect(lab.files.some((file) => file.startsWith("components/lab/"))).toBe(true);
  });

  it("maps variant aliases and default launcher titles", () => {
    expect(parseVariant(undefined)).toBe("production");
    expect(parseVariant("dev")).toBe("development");
    expect(parseVariant("lab")).toBe("lab");
    expect(() => parseVariant("qa")).toThrow("Unsupported ROKU_VARIANT");

    expect(defaultTitleForVariant("production")).toBe("put.io");
    expect(defaultTitleForVariant("development")).toBe("put.io Dev");
    expect(defaultTitleForVariant("lab")).toBe("put.io Lab");
  });

  it("renders variant manifest and build config overrides", async () => {
    const manifest = await renderVariantManifest(repoRoot, "lab", "put.io Lab");
    const buildConfig = renderBuildConfig("lab", "9999");

    expect(manifest).toContain("title=put.io Lab");
    expect(buildConfig).toContain('return "lab"');
    expect(buildConfig).toContain("return true");
    expect(buildConfig).toContain('return "9999"');
  });

  it("writes a variant package ZIP", async () => {
    rmSync(join(repoRoot, packageTestDir), { recursive: true, force: true });

    const outFile = `${packageTestDir}/put.io-lab-test.zip`;
    const result = await packageRokuApp({
      outFile,
      putioAppId: "9999",
      repoRoot,
      variant: "lab",
    });

    expect(result.outFile).toBe(join(repoRoot, outFile));
    expect(result.files).toContain("source/BuildConfig.brs");
    expect(existsSync(join(repoRoot, outFile))).toBe(true);
  });

  it("defaults lab-enabled builds to Lab on normal app launch", () => {
    const main = readFileSync(join(repoRoot, "source/Main.brs"), "utf8");
    const shouldLaunchLab = main.match(/function shouldLaunchLab\(args as object\) as boolean([\s\S]*?)end function/);

    expect(shouldLaunchLab?.[1]).toContain("if args = invalid\n        return true");
    expect(shouldLaunchLab?.[1]).toContain("if lab <> invalid");
    expect(shouldLaunchLab?.[1]).toContain("return isTruthyLaunchArg(lab) or story <> invalid");
  });
});
