import { readFile, stat } from "node:fs/promises";
import { basename, join, resolve } from "node:path";
import { createPackageZip } from "@putdotio/rokit";

export type RokuVariant = "production" | "development" | "lab";

export interface RokuPackageOptions {
  readonly appTitle?: string;
  readonly outFile: string;
  readonly putioAppId?: string;
  readonly repoRoot: string;
  readonly variant: RokuVariant;
}

export interface RokuPackageResult {
  readonly fileCount: number;
  readonly files: readonly string[];
  readonly outFile: string;
  readonly title: string;
  readonly variant: RokuVariant;
}

const appRoots = ["manifest", "source", "components", "images"] as const;

export async function packageRokuApp(options: RokuPackageOptions): Promise<RokuPackageResult> {
  const repoRoot = resolve(options.repoRoot);
  const title = options.appTitle ?? defaultTitleForVariant(options.variant);
  const outFile = resolve(repoRoot, options.outFile);
  const result = await createPackageZip({
    exclude: (path) => !shouldIncludeFile(path, options.variant),
    outFile,
    overrides: [
      {
        contents: await renderVariantManifest(repoRoot, options.variant, title),
        path: "manifest",
      },
      {
        contents: renderBuildConfig(options.variant, options.putioAppId ?? "3776"),
        path: "source/BuildConfig.brs",
      },
    ],
    rootDir: repoRoot,
    roots: appRoots,
  });

  return {
    fileCount: result.fileCount,
    files: result.files,
    outFile,
    title,
    variant: options.variant,
  };
}

export function defaultTitleForVariant(variant: RokuVariant): string {
  switch (variant) {
    case "production":
      return "put.io";
    case "development":
      return "put.io Dev";
    case "lab":
      return "put.io Lab";
  }
}

export function parseVariant(value: string | undefined): RokuVariant {
  switch (value) {
    case undefined:
    case "":
    case "production":
      return "production";
    case "development":
    case "dev":
      return "development";
    case "lab":
      return "lab";
    default:
      throw new Error(`Unsupported ROKU_VARIANT "${value}". Expected production, development, or lab.`);
  }
}

export async function renderVariantManifest(
  repoRoot: string,
  variant: RokuVariant,
  title: string,
): Promise<string> {
  let manifest = await readFile(join(repoRoot, "manifest"), "utf8");
  manifest = replaceManifestValue(manifest, "title", title);

  const assetRoot = `images/generated/${variant}`;
  if (await fileExists(join(repoRoot, assetRoot, "channel-poster_fhd.png"))) {
    manifest = replaceManifestValue(manifest, "mm_icon_focus_fhd", `pkg:/${assetRoot}/channel-poster_fhd.png`);
    manifest = replaceManifestValue(manifest, "mm_icon_focus_hd", `pkg:/${assetRoot}/channel-poster_hd.png`);
    manifest = replaceManifestValue(manifest, "mm_icon_focus_sd", `pkg:/${assetRoot}/channel-poster_sd.png`);
  }

  if (await fileExists(join(repoRoot, assetRoot, "Splash-FHD.png"))) {
    manifest = replaceManifestValue(manifest, "splash_screen_fhd", `pkg:/${assetRoot}/Splash-FHD.png`);
    manifest = replaceManifestValue(manifest, "splash_screen_hd", `pkg:/${assetRoot}/Splash-HD.png`);
    manifest = replaceManifestValue(manifest, "splash_screen_sd", `pkg:/${assetRoot}/Splash-SD.png`);
  }

  return manifest;
}

export function renderBuildConfig(variant: RokuVariant, putioAppId: string): string {
  return `function buildConfigVariant() as string
    return "${brightScriptString(variant)}"
end function

function buildConfigLabEnabled() as boolean
    return ${variant === "lab" ? "true" : "false"}
end function

function buildConfigPutioAppId() as string
    return "${brightScriptString(putioAppId)}"
end function
`;
}

function shouldIncludeFile(relativePath: string, variant: RokuVariant): boolean {
  const fileName = basename(relativePath);
  if (fileName.startsWith(".") || fileName.endsWith("~")) {
    return false;
  }

  return variant === "lab" || (relativePath !== "components/lab" && !relativePath.startsWith("components/lab/"));
}

function replaceManifestValue(manifest: string, key: string, value: string): string {
  const line = `${key}=${escapeManifestValue(value)}`;
  const pattern = new RegExp(`^${escapeRegExp(key)}=.*$`, "m");
  if (pattern.test(manifest)) {
    return manifest.replace(pattern, line);
  }

  return `${manifest.trimEnd()}\n${line}\n`;
}

function escapeManifestValue(value: string): string {
  return value.replace(/\r|\n/g, " ");
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function brightScriptString(value: string): string {
  return value.replace(/"/g, "\"\"");
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await stat(filePath);
    return true;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return false;
    }

    throw error;
  }
}
