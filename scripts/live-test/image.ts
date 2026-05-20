import {
  assertNamedNodeSize,
  assertNamedNodeTranslation,
  readNamedNodeAttribute,
} from "@putdotio/rokit";
import {
  launchDeepLink,
  waitForSceneGraphAssertion,
} from "./rokit-device.ts";
import {
  assertNamedNodeHiddenOrAbsent,
  assertNamedNodeVisible,
} from "./scenegraph.ts";

const imageViewport = {
  x: 96,
  y: 160,
  width: 1728,
  height: 824,
} as const;

export async function imageRenderSmoke(target: string, contentId: string): Promise<void> {
  await launchDeepLink(target, contentId, "image");
  await waitForSceneGraphAssertion(
    target,
    "expected image screen to render a viewport-scaled image",
    (xml) => {
      assertImageRenderSurface(xml, contentId);
    },
    30_000,
  );
  console.log(`asserted image render viewport for contentID=${contentId}`);
}

export function assertImageRenderSurface(xml: string, contentId: string): void {
  assertNamedNodeVisible(xml, "imageScreen");
  assertNamedNodeHiddenOrAbsent(xml, "loading");
  assertNamedNodeVisible(xml, "renderedImage");
  assertNamedNodeTranslation(xml, "renderedImage", imageViewport.x, imageViewport.y);
  assertNamedNodeSize(xml, "renderedImage", imageViewport.width, imageViewport.height);

  const loadStatus = readNamedNodeAttribute(xml, "renderedImage", "loadStatus");
  if (loadStatus !== "ready" && loadStatus !== "3") {
    throw new Error(`expected image loadStatus ready, got ${loadStatus ?? "missing"}`);
  }

  const uri = readNamedNodeAttribute(xml, "renderedImage", "uri");
  if (uri === undefined || !uri.includes(`/files/${contentId}/download`)) {
    throw new Error(`expected image uri to include /files/${contentId}/download`);
  }
}
