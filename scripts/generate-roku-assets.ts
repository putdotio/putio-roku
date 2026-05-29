import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { Resvg } from "@resvg/resvg-js";
import { toRokuColor } from "./generate-roku-design.ts";

type AssetVariant = "production" | "development" | "lab";
type AssetKind = "poster" | "splash";
type TokenMap = { readonly [key: string]: unknown };

interface AssetStyle {
  readonly accentColor: string;
  readonly backgroundColor: string;
  readonly brandAccentColor: string;
  readonly foregroundColor?: string;
  readonly gridColor?: SvgColor;
}

interface AssetSize {
  readonly fileName: string;
  readonly height: number;
  readonly width: number;
}

interface SvgColor {
  readonly color: string;
  readonly opacity?: string;
}

const posterSizes: readonly AssetSize[] = [
  { fileName: "channel-poster_fhd.png", width: 540, height: 405 },
  { fileName: "channel-poster_hd.png", width: 290, height: 218 },
  { fileName: "channel-poster_sd.png", width: 246, height: 140 },
];

const splashSizes: readonly AssetSize[] = [
  { fileName: "Splash-FHD.png", width: 1920, height: 1080 },
  { fileName: "Splash-HD.png", width: 1280, height: 720 },
  { fileName: "Splash-SD.png", width: 720, height: 480 },
];

const logoSourceAccentColor = "#FDCE45";

export async function generateRokuAssets(repoRoot: string): Promise<readonly string[]> {
  const designAssetsDir = await resolveDesignAssetsDir(repoRoot);
  const tokens = await readTokenMap(resolveTokenPath(repoRoot));
  const logo = await readLogo(resolve(designAssetsDir, "logo-retro-dark.svg"));
  const outputs: string[] = [];

  for (const variant of ["production", "development", "lab"]) {
    const assetVariant = parseAssetVariant(variant);
    const outputDir = resolve(repoRoot, `images/generated/${assetVariant}`);
    await mkdir(outputDir, { recursive: true });

    for (const size of posterSizes) {
      const outputPath = resolve(outputDir, size.fileName);
      await renderSvgToPng(renderAssetSvg(logo, assetStyleFromTokens(tokens, assetVariant, "poster"), "poster", size), outputPath);
      outputs.push(outputPath);
    }

    for (const size of splashSizes) {
      const outputPath = resolve(outputDir, size.fileName);
      await renderSvgToPng(renderAssetSvg(logo, assetStyleFromTokens(tokens, assetVariant, "splash"), "splash", size), outputPath);
      outputs.push(outputPath);
    }
  }

  return outputs;
}

async function renderSvgToPng(svg: string, outputPath: string): Promise<void> {
  const png = new Resvg(svg, { fitTo: { mode: "original" } }).render().asPng();
  await writeFile(outputPath, png);
}

async function resolveDesignAssetsDir(repoRoot: string): Promise<string> {
  const explicitPath = process.env.PUTIO_DESIGN_ASSETS_DIR;
  if (explicitPath !== undefined && explicitPath !== "") {
    return resolve(repoRoot, explicitPath);
  }

  try {
    return dirname(fileURLToPath(import.meta.resolve("@putdotio/design/assets/logo-retro-dark.svg")));
  } catch (error) {
    throw new Error(
      "Could not resolve @putdotio/design/assets/logo-retro-dark.svg. Update @putdotio/design or set PUTIO_DESIGN_ASSETS_DIR for an explicit asset source.",
      { cause: error },
    );
  }
}

function resolveTokenPath(repoRoot: string): string {
  const explicitPath = process.env.PUTIO_DESIGN_TOKENS_PATH;
  if (explicitPath !== undefined && explicitPath !== "") {
    return resolve(repoRoot, explicitPath);
  }

  try {
    return fileURLToPath(import.meta.resolve("@putdotio/design/tokens"));
  } catch (error) {
    throw new Error(
      "Could not resolve @putdotio/design/tokens. Install or update @putdotio/design.",
      { cause: error },
    );
  }
}

function parseAssetVariant(value: string): AssetVariant {
  switch (value) {
    case "production":
      return "production";
    case "development":
      return "development";
    case "lab":
      return "lab";
    default:
      throw new Error(`Unsupported asset variant: ${value}`);
  }
}

async function readLogo(path: string): Promise<string> {
  const svg = await readFile(path, "utf8");
  const match = /<svg\b[^>]*>([\s\S]*)<\/svg>/i.exec(svg);
  if (match?.[1] === undefined) {
    throw new Error(`Could not parse logo SVG: ${path}`);
  }

  return match[1];
}

export function renderAssetSvg(
  logo: string,
  style: AssetStyle,
  kind: AssetKind,
  size: AssetSize,
): string {
  const logoWidth = logoWidthFor(kind, size);
  const logoHeight = Math.round(logoWidth * 96 / 376);
  const logoX = Math.round((size.width - logoWidth) / 2);
  const logoY = Math.round((size.height - logoHeight) / 2);
  const logoScale = logoWidth / 376;
  const transformedLogo = tintLogo(logo, style.brandAccentColor, style.accentColor, style.foregroundColor);

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size.width}" height="${size.height}" viewBox="0 0 ${size.width} ${size.height}">
  <rect width="${size.width}" height="${size.height}" fill="${style.backgroundColor}" />
  ${style.gridColor ? renderGrid(size, style.gridColor) : ""}
  <g transform="translate(${logoX} ${logoY}) scale(${logoScale})">
    ${transformedLogo}
  </g>
</svg>
`;
}

export function assetStyleFromTokens(
  tokens: TokenMap,
  variant: AssetVariant,
  kind: AssetKind,
): AssetStyle {
  const brandAccentColor = toSvgPaint(readTokenValue(tokens, "color.brand.yellow"));

  switch (variant) {
    case "production":
      return {
        accentColor: brandAccentColor,
        backgroundColor: toSvgPaint(
          readTokenValue(
            tokens,
            kind === "poster"
              ? "context.tv.channelArt.production.posterBackground"
              : "context.tv.channelArt.production.splashBackground",
          ),
        ),
        brandAccentColor,
      };
    case "development":
      return {
        accentColor: toSvgPaint(readTokenValue(tokens, "context.tv.channelArt.development.accent")),
        backgroundColor: toSvgPaint(readTokenValue(tokens, "context.tv.channelArt.development.background")),
        brandAccentColor,
        gridColor: toSvgColor(readTokenValue(tokens, "context.tv.channelArt.development.grid")),
      };
    case "lab":
      return {
        accentColor: toSvgPaint(readTokenValue(tokens, "context.tv.channelArt.lab.accent")),
        backgroundColor: toSvgPaint(readTokenValue(tokens, "context.tv.channelArt.lab.background")),
        brandAccentColor,
        foregroundColor: toSvgPaint(readTokenValue(tokens, "context.tv.channelArt.lab.foreground")),
      };
  }
}

function logoWidthFor(kind: AssetKind, size: AssetSize): number {
  if (kind === "poster") {
    return Math.round(size.width * 0.76);
  }

  return Math.round(size.width * 0.56);
}

async function readTokenMap(tokenPath: string): Promise<TokenMap> {
  const parsed = JSON.parse(await readFile(tokenPath, "utf8"));
  if (!isObject(parsed)) {
    throw new Error(`Expected token map object in ${tokenPath}`);
  }

  return parsed;
}

function readTokenValue(tokens: TokenMap, key: string): string {
  const entry = tokens[key];
  if (isObject(entry) && typeof entry.value === "string") {
    return entry.value;
  }

  throw new Error(`Missing required design token: ${key}`);
}

function toSvgColor(value: string): SvgColor {
  const normalized = value.trim();
  const hexMatch = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(normalized);
  if (hexMatch !== null) {
    const raw = hexMatch[1] ?? "";
    const color = raw.length === 3
      ? raw.split("").map((part) => `${part}${part}`).join("")
      : raw;
    return { color: `#${color.toUpperCase()}` };
  }

  const rgbaMatch = /^rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*(0|1|0?\.\d+)\s*\)$/i.exec(normalized);
  if (rgbaMatch !== null) {
    const red = parseColorChannel(rgbaMatch[1], value);
    const green = parseColorChannel(rgbaMatch[2], value);
    const blue = parseColorChannel(rgbaMatch[3], value);
    return {
      color: `#${toHex(red)}${toHex(green)}${toHex(blue)}`,
      opacity: rgbaMatch[4],
    };
  }

  const rokuColor = toRokuColor(normalized);
  const rokuColorMatch = /^0x([0-9A-F]{6})([0-9A-F]{2})$/.exec(rokuColor);
  if (rokuColorMatch === null) {
    throw new Error(`Unsupported SVG color token value: ${value}`);
  }

  const alpha = Number.parseInt(rokuColorMatch[2] ?? "FF", 16);
  return {
    color: `#${rokuColorMatch[1]}`,
    opacity: alpha === 255 ? undefined : String(alpha / 255),
  };
}

function toSvgPaint(value: string): string {
  const svgColor = toSvgColor(value);
  if (svgColor.opacity !== undefined && svgColor.opacity !== "1") {
    throw new Error(`Expected opaque SVG paint token value: ${value}`);
  }

  return svgColor.color;
}

function tintLogo(logo: string, sourceAccentColor: string, accentColor: string, foregroundColor?: string): string {
  const foregroundTinted = foregroundColor === undefined
    ? logo
    : logo
      .replace(/\bwhite\b/gi, foregroundColor)
      .replace(/#(?:fff|ffffff)\b/gi, foregroundColor);

  return uniqueColors([sourceAccentColor, logoSourceAccentColor]).reduce(
    (currentLogo, sourceColor) => currentLogo.replace(new RegExp(escapeRegExp(sourceColor), "gi"), accentColor),
    foregroundTinted,
  );
}

function uniqueColors(colors: readonly string[]): readonly string[] {
  const seen = new Set<string>();
  const unique: string[] = [];

  for (const color of colors) {
    const normalized = color.toLowerCase();
    if (!seen.has(normalized)) {
      seen.add(normalized);
      unique.push(color);
    }
  }

  return unique;
}

function renderGrid(size: AssetSize, gridColor: SvgColor): string {
  const step = Math.max(12, Math.round(size.width / 16));
  const lines: string[] = [];
  const opacity = gridColor.opacity ? ` stroke-opacity="${gridColor.opacity}"` : "";
  for (let x = 0; x <= size.width; x += step) {
    lines.push(`<line x1="${x}" y1="0" x2="${x}" y2="${size.height}" stroke="${gridColor.color}"${opacity} />`);
  }

  for (let y = 0; y <= size.height; y += step) {
    lines.push(`<line x1="0" y1="${y}" x2="${size.width}" y2="${y}" stroke="${gridColor.color}"${opacity} />`);
  }

  return `<g>${lines.join("")}</g>`;
}

function parseColorChannel(value: string | undefined, source: string): number {
  if (value === undefined) {
    throw new Error(`Unsupported SVG color token value: ${source}`);
  }

  const channel = Number(value);
  if (!Number.isInteger(channel) || channel < 0 || channel > 255) {
    throw new Error(`Unsupported SVG color channel in ${source}`);
  }

  return channel;
}

function toHex(channel: number): string {
  return channel.toString(16).padStart(2, "0").toUpperCase();
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function isObject(value: unknown): value is TokenMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function main(): Promise<void> {
  const outputs = await generateRokuAssets(process.cwd());
  console.log(`Generated ${outputs.length} Roku image assets`);
}

if (process.argv[1] !== undefined && process.argv[1].endsWith("generate-roku-assets.ts")) {
  await main();
}
