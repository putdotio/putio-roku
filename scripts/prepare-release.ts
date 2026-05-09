#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";

const version = process.argv[2];

if (!version) {
  console.error("usage: scripts/prepare-release.ts <version>");
  process.exit(1);
}

type ReleaseVersion = {
  major: number;
  minor: number;
  patch: number;
  value: string;
};

function readText(path: string): string {
  return readFileSync(path, "utf8");
}

function writeText(path: string, text: string): void {
  writeFileSync(path, text.endsWith("\n") ? text : `${text}\n`);
}

function replaceRequired(
  text: string,
  pattern: RegExp,
  replacement: string,
  path: string,
): string {
  if (!pattern.test(text)) {
    throw new Error(`missing expected release field in ${path}: ${pattern}`);
  }

  return text.replace(pattern, replacement);
}

function readRequiredField(path: string, text: string, pattern: RegExp): string {
  const match = pattern.exec(text);

  if (!match?.[1]) {
    throw new Error(`missing expected release field in ${path}: ${pattern}`);
  }

  return match[1];
}

function parseReleaseVersion(value: string): ReleaseVersion {
  const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(value);

  if (!match) {
    throw new Error(`invalid release version: ${value}`);
  }

  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
    value,
  };
}

function readManifestVersion(): ReleaseVersion {
  const manifestPath = "manifest";
  const manifest = readText(manifestPath);
  const major = readRequiredField(manifestPath, manifest, /^major_version=(\d+)$/m);
  const minor = readRequiredField(manifestPath, manifest, /^minor_version=(\d+)$/m);
  const build = readRequiredField(manifestPath, manifest, /^build_version=(\d+)$/m);

  return parseReleaseVersion(`${Number(major)}.${Number(minor)}.${Number(build)}`);
}

function compareVersions(left: ReleaseVersion, right: ReleaseVersion): number {
  const fields = ["major", "minor", "patch"] as const;

  for (const field of fields) {
    if (left[field] !== right[field]) {
      return left[field] - right[field];
    }
  }

  return 0;
}

function syncVersion(): void {
  const releaseVersion = parseReleaseVersion(version);
  const manifestVersion = readManifestVersion();

  if (compareVersions(releaseVersion, manifestVersion) < 0) {
    throw new Error(
      `semantic-release computed ${version}, but manifest is ${manifestVersion.value}`,
    );
  }

  const packagePath = "package.json";
  const packageJson: unknown = JSON.parse(readText(packagePath));

  if (
    typeof packageJson !== "object" ||
    packageJson === null ||
    Array.isArray(packageJson)
  ) {
    throw new Error(`${packagePath} must contain a JSON object`);
  }

  Object.assign(packageJson, { version });
  writeText(packagePath, JSON.stringify(packageJson, null, 2));

  const manifestPath = "manifest";
  let manifest = readText(manifestPath);
  manifest = replaceRequired(
    manifest,
    /^major_version=.*$/m,
    `major_version=${releaseVersion.major}`,
    manifestPath,
  );
  manifest = replaceRequired(
    manifest,
    /^minor_version=.*$/m,
    `minor_version=${releaseVersion.minor}`,
    manifestPath,
  );
  manifest = replaceRequired(
    manifest,
    /^build_version=.*$/m,
    `build_version=${String(releaseVersion.patch).padStart(5, "0")}`,
    manifestPath,
  );
  writeText(manifestPath, manifest);

  const makefilePath = "Makefile";
  let makefile = readText(makefilePath);
  makefile = replaceRequired(
    makefile,
    /^VERSION = .*$/m,
    `VERSION = ${version}`,
    makefilePath,
  );
  writeText(makefilePath, makefile);
}

function runMakeArtifact(): void {
  const result = spawnSync("make", ["artifact"], { stdio: "inherit" });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(
      `make artifact failed with status ${result.status ?? "unknown"}`,
    );
  }
}

function stageReleaseFiles(): void {
  const sourceZip = "dist/apps/putio-roku-v2.zip";

  if (!existsSync(sourceZip)) {
    throw new Error(`missing release artifact: ${sourceZip}`);
  }

  rmSync("dist/public", { recursive: true, force: true });
  rmSync("dist/release", { recursive: true, force: true });
  mkdirSync("dist/public/releases/v2", { recursive: true });
  mkdirSync("dist/release", { recursive: true });

  copyFileSync(sourceZip, "dist/public/v2.zip");
  copyFileSync(sourceZip, `dist/public/releases/v2/${version}.zip`);
  copyFileSync(sourceZip, `dist/release/putio-roku-v${version}.zip`);
}

syncVersion();
runMakeArtifact();
stageReleaseFiles();

console.log(`Prepared Roku release ${version}`);
console.log("- dist/public/v2.zip");
console.log(`- dist/public/releases/v2/${version}.zip`);
console.log(`- dist/release/putio-roku-v${version}.zip`);
