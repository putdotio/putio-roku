import { copyFile, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { Resvg } from "@resvg/resvg-js";

const manifestPath = "config/phosphor-icons.json";
const iconsOutputDir = "images/icons";
const licenseOutputPath = "third-party/phosphor-icons/LICENSE";

// Phosphor sources are a square 256 viewBox with no intrinsic size. Rasterizing at
// 128px keeps every on-device usage (22px mini glyph up to the 128px audio transport
// buttons) crisp while staying small for a monochrome template.
const iconRenderSize = 128;
const packageName = "@phosphor-icons/core";
const allowedWeights = ["regular", "fill"] as const;
const iconNamePattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

type IconWeight = (typeof allowedWeights)[number];

interface IconEntry {
  readonly asset: string;
  readonly name: string;
  readonly weight: IconWeight;
}

interface PhosphorManifest {
  readonly package: { readonly name: string; readonly version: string };
  readonly icons: readonly IconEntry[];
}

export async function generateRokuIcons(repoRoot: string): Promise<readonly string[]> {
  const manifest = await readManifest(resolve(repoRoot, manifestPath));
  const coreDir = await resolvePhosphorCoreDir(repoRoot);
  await assertPackageVersion(coreDir, manifest.package);

  const targetDir = resolve(repoRoot, iconsOutputDir);
  await mkdir(targetDir, { recursive: true });

  const outputs: string[] = [];
  for (const icon of manifest.icons) {
    const svg = await readIconSvg(coreDir, icon, manifest.package.version);
    const outputPath = resolve(targetDir, `${icon.asset}.png`);
    await writeFile(outputPath, renderIcon(svg));
    outputs.push(outputPath);
  }

  await pruneUnlistedIcons(targetDir, manifest.icons);
  await copyLicense(coreDir, resolve(repoRoot, licenseOutputPath));

  return outputs;
}

function renderIcon(svg: string): Buffer {
  const template = svg.replace(/currentColor/g, "#FFFFFF");
  return new Resvg(template, { fitTo: { mode: "width", value: iconRenderSize } }).render().asPng();
}

async function readManifest(path: string): Promise<PhosphorManifest> {
  return parseIconManifest(JSON.parse(await readFile(path, "utf8")));
}

export function parseIconManifest(parsed: unknown): PhosphorManifest {
  if (!isObject(parsed)) {
    throw new Error(`Expected an object in ${manifestPath}`);
  }

  const pkg = parsed.package;
  if (!isObject(pkg) || pkg.name !== packageName || typeof pkg.version !== "string") {
    throw new Error(`${manifestPath} must pin package.name "${packageName}" and a package.version string`);
  }

  if (!Array.isArray(parsed.icons)) {
    throw new Error(`${manifestPath} must contain an icons array`);
  }

  const assets = new Set<string>();
  const icons = parsed.icons.map((entry, index) => validateIcon(entry, index, assets));

  return { package: { name: pkg.name, version: pkg.version }, icons };
}

function validateIcon(entry: unknown, index: number, assets: Set<string>): IconEntry {
  if (!isObject(entry)) {
    throw new Error(`Icon at index ${index} must be an object`);
  }

  const keys = Object.keys(entry).sort();
  if (keys.join(",") !== "asset,name,weight") {
    throw new Error(`Icon at index ${index} must contain only asset, name and weight`);
  }

  const { asset, name, weight } = entry;
  if (typeof asset !== "string" || !iconNamePattern.test(asset)) {
    throw new Error(`Invalid Phosphor icon asset name: ${JSON.stringify(asset)}`);
  }
  if (typeof name !== "string" || !iconNamePattern.test(name)) {
    throw new Error(`Invalid Phosphor icon name: ${JSON.stringify(name)}`);
  }
  if (typeof weight !== "string" || !isWeight(weight)) {
    throw new Error(`Unsupported Phosphor icon weight for ${asset}: ${JSON.stringify(weight)}`);
  }
  if (assets.has(asset)) {
    throw new Error(`Duplicate Phosphor icon asset: ${asset}`);
  }

  assets.add(asset);
  return { asset, name, weight };
}

async function resolvePhosphorCoreDir(repoRoot: string): Promise<string> {
  const override = process.env.PUTIO_PHOSPHOR_CORE_DIR;
  if (override !== undefined && override !== "") {
    return resolve(repoRoot, override);
  }

  try {
    // "@phosphor-icons/core" resolves to <coreDir>/dist/index.mjs; step up to the package root.
    return dirname(dirname(fileURLToPath(import.meta.resolve(packageName))));
  } catch (error) {
    throw new Error(
      `Could not resolve ${packageName}. Run pnpm install or set PUTIO_PHOSPHOR_CORE_DIR to an explicit package directory.`,
      { cause: error },
    );
  }
}

async function assertPackageVersion(
  coreDir: string,
  expected: { readonly name: string; readonly version: string },
): Promise<void> {
  const parsed: unknown = JSON.parse(await readFile(join(coreDir, "package.json"), "utf8"));
  if (!isObject(parsed) || parsed.name !== expected.name || parsed.version !== expected.version) {
    const actual = isObject(parsed) ? `${String(parsed.name)}@${String(parsed.version)}` : "unknown";
    throw new Error(
      `Installed ${actual} does not match ${manifestPath} pin ${expected.name}@${expected.version}. Update the manifest and package.json together.`,
    );
  }
}

async function readIconSvg(coreDir: string, icon: IconEntry, version: string): Promise<string> {
  const fileName = icon.weight === "regular" ? `${icon.name}.svg` : `${icon.name}-${icon.weight}.svg`;
  const path = join(coreDir, "assets", icon.weight, fileName);
  try {
    return await readFile(path, "utf8");
  } catch (error) {
    throw new Error(
      `Missing Phosphor source assets/${icon.weight}/${fileName} for "${icon.asset}" in ${packageName} ${version}.`,
      { cause: error },
    );
  }
}

async function pruneUnlistedIcons(targetDir: string, icons: readonly IconEntry[]): Promise<void> {
  const expected = new Set(icons.map((icon) => `${icon.asset}.png`));
  for (const entry of await readdir(targetDir)) {
    if (entry.endsWith(".png") && !expected.has(entry)) {
      await rm(join(targetDir, entry));
    }
  }
}

async function copyLicense(coreDir: string, destination: string): Promise<void> {
  await mkdir(dirname(destination), { recursive: true });
  await copyFile(join(coreDir, "LICENSE"), destination);
}

function isWeight(value: string): value is IconWeight {
  return (allowedWeights as readonly string[]).includes(value);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function main(): Promise<void> {
  const outputs = await generateRokuIcons(process.cwd());
  console.log(`Generated ${outputs.length} Roku icon assets`);
}

if (process.argv[1] !== undefined && process.argv[1].endsWith("generate-roku-icons.ts")) {
  await main();
}
