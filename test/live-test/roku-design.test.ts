import { describe, expect, it } from "vitest";
import { assetStyleFromTokens, renderAssetSvg } from "../../scripts/generate-roku-assets.ts";
import { renderDesignTokens, toRokuColor } from "../../scripts/generate-roku-design.ts";
import { repoRoot } from "./repo-files.ts";

const sampleLogo = '<path d="M0 0H376V96H0Z" fill="white"></path><path d="M0 0H10V10H0Z" fill="#FDCE45"></path>';
const sampleTokens = {
  "color.brand.yellow": { value: "hsl(44.7, 97.9%, 63.1%)" },
  "context.tv.channelArt.production.posterBackground": { value: "#333333" },
  "context.tv.channelArt.production.splashBackground": { value: "hsl(0, 0%, 8.5%)" },
  "context.tv.channelArt.development.background": { value: "#248FE5" },
  "context.tv.channelArt.development.accent": { value: "#9FD5FF" },
  "context.tv.channelArt.development.grid": { value: "rgba(255,255,255,0.18)" },
  "context.tv.channelArt.lab.background": { value: "#0a0f0a" },
  "context.tv.channelArt.lab.foreground": { value: "#e8ffe4" },
  "context.tv.channelArt.lab.accent": { value: "#39FF14" },
};

describe("Roku design adapter", () => {
  it("converts design-system colors to Roku color strings", () => {
    expect([
      toRokuColor("#FDCE45"),
      toRokuColor("#000"),
      toRokuColor("#a0a0a0"),
      toRokuColor("hsl(0, 0%, 8.5%)"),
      toRokuColor("hsla(0, 0%, 0%, 0.565)"),
      toRokuColor("transparent"),
    ]).toEqual([
      "0xFDCE45FF",
      "0x000000FF",
      "0xA0A0A0FF",
      "0x161616FF",
      "0x00000090",
      "0x00000000",
    ]);
  });

  it("renders BrightScript token lookup without local filesystem paths", () => {
    const output = renderDesignTokens(
      [{ name: "primary", value: "0xFDCE45FF" }],
      "@putdotio/design/tokens",
    );

    expect(output).toContain("function designTokenColor");
    expect(output).toContain('primary: "0xFDCE45FF"');
    expect(output).not.toContain(repoRoot);
  });

  it("renders distinct variant channel art from design tokens", () => {
    const productionPoster = renderAsset("production", "poster", 540, 405);
    const productionSplash = renderAsset("production", "splash", 1920, 1080);
    const developmentPoster = renderAsset("development", "poster", 540, 405);
    const labSplash = renderAsset("lab", "splash", 1920, 1080);

    expect(productionPoster).toContain('fill="#333333"');
    expect(productionPoster).toContain("#FDCE45");
    expect(productionPoster).toContain("scale(");
    expect(productionPoster).not.toContain("app-icon");

    expect(productionSplash).toContain('fill="#161616"');
    expect(productionSplash).toContain("#FDCE45");
    expect(productionSplash).not.toContain("hsl(");

    expect(developmentPoster).toContain('fill="#248FE5"');
    expect(developmentPoster).toContain('stroke-opacity="0.18"');
    expect(developmentPoster).toContain("#9FD5FF");
    expect(developmentPoster).not.toContain("#FDCE45");

    expect(labSplash).toContain('fill="#0A0F0A"');
    expect(labSplash).toContain("#E8FFE4");
    expect(labSplash).toContain("#39FF14");
    expect(labSplash).not.toContain("#FDCE45");
  });

  it("requires design-token-backed channel art colors", () => {
    expect(() => assetStyleFromTokens({}, "lab", "poster")).toThrow("Missing required design token");
  });
});

function renderAsset(
  variant: "production" | "development" | "lab",
  kind: "poster" | "splash",
  width: number,
  height: number,
): string {
  return renderAssetSvg(
    sampleLogo,
    assetStyleFromTokens(sampleTokens, variant, kind),
    kind,
    { fileName: `${kind}.png`, width, height },
  );
}
