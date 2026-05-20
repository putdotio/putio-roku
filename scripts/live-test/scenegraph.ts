import {
  assertNamedNodeSize as assertNodeSize,
  assertNamedNodeState,
  assertNamedNodeTranslation as assertNodeTranslation,
  isNamedNodeVisible,
  readNamedNodeAttribute,
  readNamedNodeBounds,
  readNamedNodeTranslation,
} from "@putdotio/rokit";
import { trackMenuRowPoolSize } from "./constants.ts";

export type TrackMenuTitle = "Audio tracks" | "Subtitles" | "Playback speed";

export function assertNamedNodeVisible(xml: string, nodeName: string): void {
  assertNamedNodeState(xml, nodeName, "visible");
}

export function assertNamedNodeHidden(xml: string, nodeName: string): void {
  assertNamedNodeState(xml, nodeName, "hidden");
}

export function assertNamedNodeHiddenOrAbsent(xml: string, nodeName: string): void {
  if (isNamedNodeVisible(xml, nodeName)) {
    throw new Error(`expected SceneGraph node "${nodeName}" to be hidden or absent`);
  }
}

export function assertNamedNodeAbsent(xml: string, nodeName: string): void {
  assertNamedNodeState(xml, nodeName, "absent");
}

export function assertPlayerOsdLayout(xml: string, progressFocused = true): void {
  assertNamedNodeAbsent(xml, "bottomShadeSoft0");
  assertNodeTranslation(xml, "bottomShade", 0, 800);
  assertNodeSize(xml, "bottomShade", 1920, 280);
  assertNodeTranslation(xml, "playerTitle", 96, 900);
  assertNodeSize(xml, "playerTitle", 1360, 46);
  assertNodeTranslation(xml, "controls", 0, 870);
  assertNamedNodeHidden(xml, "rewindButton");
  assertNamedNodeHidden(xml, "playButton");
  assertNamedNodeHidden(xml, "fastForwardButton");
  assertTitleDoesNotOverlapAuxiliaryControls(xml);
  assertAuxiliaryControlsLayout(xml);
  assertNodeTranslation(xml, "progress", 96, 960);
  assertNodeTranslation(xml, "playerProgressTrack", 0, progressFocused ? 23 : 25);
  assertNodeSize(xml, "playerProgressTrack", 1728, progressFocused ? 12 : 8);
  assertNodeTranslation(xml, "playerDuration", 1548, 52);
}

export function assertFocusedAuxiliaryLabelLayout(xml: string, focusLabelNodeName: string): void {
  assertNodeTranslation(xml, focusLabelNodeName, -86, -44);
  assertNodeSize(xml, focusLabelNodeName, 260, 36);
}

export function assertTrackMenuLayout(
  xml: string,
  expectedTitle: TrackMenuTitle,
  selectedRowIndex: number,
): void {
  const rowBackgroundName = `trackMenuRow${selectedRowIndex}Background`;
  const rowCheckName = `trackMenuRow${selectedRowIndex}Check`;
  const visibleRowCount = countVisibleTrackRows(xml);
  const rowHeight = 62;
  const rowGap = 8;
  const panelHeight = 108 + 44 + visibleRowCount * rowHeight + Math.max(0, visibleRowCount - 1) * rowGap;
  const panelY = Math.round((1080 - panelHeight) / 2);

  assertNodeTranslation(xml, "trackMenuPanel", 550, panelY);
  assertScopedNodeSize(xml, "trackMenuPanel", "panelFill", 820, panelHeight);
  assertScopedNodeSize(xml, "trackMenuPanel", "panelShadow", 820, panelHeight);
  assertNodeTranslation(xml, "trackMenuTitle", 48, 44);
  assertNodeTranslation(xml, "trackRows", 48, 108);
  assertNodeSize(xml, rowBackgroundName, 724, 62);
  assertNodeTranslation(xml, rowCheckName, 660, 8);
}

export function hasVisibleNode(xml: string, tagName: string, nodeName: string): boolean {
  const nodePattern = new RegExp(
    `<${tagName}\\b(?=[^>]*\\bname="${nodeName}")([^>]*)>`,
  );
  const match = nodePattern.exec(xml);

  return match !== null && !match[1]?.includes('visible="false"');
}

export function hasVisibleComponent(xml: string, tagName: string): boolean {
  const nodePattern = new RegExp(`<${tagName}\\b([^>]*)>`);
  const match = nodePattern.exec(xml);

  return match !== null && !match[1]?.includes('visible="false"');
}

export function hasVisibleRouteScreen(xml: string, screenName: string): boolean {
  const tagName = routeScreenTagName(screenName);

  return (
    tagName !== undefined &&
    (hasVisibleNode(xml, tagName, screenName) || hasVisibleComponent(xml, tagName))
  );
}

export function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function readNamedNodeIntegerAttribute(
  xml: string,
  nodeName: string,
  attributeName: string,
): number {
  const nodePattern = new RegExp(`<[^>]+\\bname="${escapeRegExp(nodeName)}"[^>]*>`);
  const nodeTag = nodePattern.exec(xml)?.[0];
  const attributePattern = new RegExp(`\\b${escapeRegExp(attributeName)}="([^"]*)"`);
  const rawValue = nodeTag === undefined ? undefined : attributePattern.exec(nodeTag)?.[1];
  const value = Number.parseInt(rawValue ?? "", 10);

  if (!Number.isInteger(value)) {
    throw new Error(`expected ${nodeName}.${attributeName} to be an integer`);
  }

  return value;
}

export function readListFocusIndex(xml: string, nodeName: string): number {
  return (
    readNamedNodeOptionalIntegerAttribute(xml, nodeName, "focusItem") ??
    readNamedNodeOptionalIntegerAttribute(xml, nodeName, "itemFocused") ??
    0
  );
}

function assertTitleDoesNotOverlapAuxiliaryControls(xml: string): void {
  const titleBounds = readNamedNodeBounds(xml, "playerTitle");
  const controlsTranslation = readNamedNodeTranslation(xml, "controls");

  if (titleBounds === undefined || controlsTranslation === undefined) {
    throw new Error("expected bounds for playerTitle and translation for controls");
  }

  for (const controlNodeName of ["audioButton", "captionsButton", "speedButton"]) {
    if (!isNamedNodeVisible(xml, controlNodeName)) {
      continue;
    }

    const controlBounds = readNamedNodeBounds(xml, controlNodeName);

    if (controlBounds === undefined) {
      throw new Error(`expected bounds for ${controlNodeName}`);
    }

    const absoluteControlBounds = [
      controlsTranslation[0] + controlBounds[0],
      controlsTranslation[1] + controlBounds[1],
      controlBounds[2],
      controlBounds[3],
    ] as const;

    if (boundsOverlap(titleBounds, absoluteControlBounds)) {
      throw new Error(
        `expected playerTitle bounds ${titleBounds.join(",")} not to overlap ${controlNodeName} bounds ${absoluteControlBounds.join(",")}`,
      );
    }
  }
}

function boundsOverlap(
  firstBounds: readonly [number, number, number, number],
  secondBounds: readonly [number, number, number, number],
): boolean {
  const [firstX, firstY, firstWidth, firstHeight] = firstBounds;
  const [secondX, secondY, secondWidth, secondHeight] = secondBounds;

  return (
    firstX < secondX + secondWidth &&
    firstX + firstWidth > secondX &&
    firstY < secondY + secondHeight &&
    firstY + firstHeight > secondY
  );
}

function assertAuxiliaryControlsLayout(xml: string): void {
  const visibleAuxiliaryControls = [
    ["audioButton", "audioFocusLabel", "audioIcon"],
    ["captionsButton", "captionsFocusLabel", "captionsIcon"],
    ["speedButton", "speedFocusLabel", "speedIcon"],
  ].filter(([buttonName]) => isNamedNodeVisible(xml, buttonName));

  const controlGap = 24;
  const controlWidth = 88;
  const auxiliaryWidth =
    visibleAuxiliaryControls.length * controlWidth +
    Math.max(0, visibleAuxiliaryControls.length - 1) * controlGap;
  let nextX = 1824 - auxiliaryWidth;

  for (const [buttonName, labelName, valueName] of visibleAuxiliaryControls) {
    assertNodeTranslation(xml, buttonName, nextX, 0);

    if (isNamedNodeVisible(xml, labelName)) {
      assertNodeTranslation(xml, labelName, -86, -44);
      assertNodeSize(xml, labelName, 260, 36);
    }

    assertNodeTranslation(xml, valueName, 16, 16);
    assertNodeSize(xml, valueName, 56, 56);

    nextX += controlWidth + controlGap;
  }
}

function assertScopedNodeSize(
  xml: string,
  scopeNodeName: string,
  nodeName: string,
  expectedWidth: number,
  expectedHeight: number,
): void {
  const bounds = parseSceneGraphNumberList(
    readScopedNodeAttribute(xml, scopeNodeName, nodeName, "bounds"),
    4,
    `${nodeName}.bounds`,
  );
  const width = bounds[2];
  const height = bounds[3];

  if (width !== expectedWidth) {
    throw new Error(`expected ${nodeName} width ${expectedWidth}, got ${width}`);
  }

  if (height !== expectedHeight) {
    throw new Error(`expected ${nodeName} height ${expectedHeight}, got ${height}`);
  }
}

function readScopedNodeAttribute(
  xml: string,
  scopeNodeName: string,
  nodeName: string,
  attributeName: string,
): string {
  const scopePattern = new RegExp(`<[^>]+\\bname="${escapeRegExp(scopeNodeName)}"[^>]*>`);
  const scopeMatch = scopePattern.exec(xml);

  if (scopeMatch === null) {
    throw new Error(`expected scoped node ${scopeNodeName}`);
  }

  const scopedXml = xml.slice(scopeMatch.index + scopeMatch[0].length);
  const nodePattern = new RegExp(`<[^>]+\\bname="${escapeRegExp(nodeName)}"[^>]*>`);
  const nodeTag = nodePattern.exec(scopedXml)?.[0];

  if (nodeTag === undefined) {
    throw new Error(`expected ${nodeName} inside ${scopeNodeName}`);
  }

  const attributePattern = new RegExp(`\\b${escapeRegExp(attributeName)}="([^"]*)"`);
  const rawValue = attributePattern.exec(nodeTag)?.[1];

  if (rawValue === undefined) {
    throw new Error(`expected ${nodeName}.${attributeName} inside ${scopeNodeName}`);
  }

  return rawValue;
}

function parseSceneGraphNumberList(
  rawValue: string,
  expectedLength: number,
  context: string,
): number[] {
  const values = rawValue
    .replace(/[{}]/g, "")
    .split(",")
    .map((part) => Number.parseFloat(part.trim()));

  if (values.length !== expectedLength || values.some((value) => !Number.isFinite(value))) {
    throw new Error(`expected ${context} to contain ${expectedLength} numbers`);
  }

  return values;
}

function countVisibleTrackRows(xml: string): number {
  let visibleRows = 0;

  for (let index = 0; index < trackMenuRowPoolSize; index += 1) {
    if (isNamedNodeVisible(xml, `trackMenuRow${index}`)) {
      visibleRows += 1;
    }
  }

  return visibleRows;
}

function routeScreenTagName(screenName: string): string | undefined {
  const screenTagNames: Record<string, string> = {
    splashScreen: "SplashScreen",
    authScreen: "AuthScreen",
    homeScreen: "HomeScreen",
    searchScreen: "SearchScreen",
    historyScreen: "HistoryScreen",
    filesScreen: "FilesScreen",
    videoScreen: "VideoScreen",
    videoPlayerScreen: "VideoPlayerScreen",
    audioScreen: "AudioScreen",
    imageScreen: "ImageScreen",
    settingsScreen: "SettingsScreen",
  };

  return screenTagNames[screenName];
}

function readNamedNodeOptionalIntegerAttribute(
  xml: string,
  nodeName: string,
  attributeName: string,
): number | undefined {
  const rawValue = readNamedNodeAttribute(xml, nodeName, attributeName);

  if (rawValue === undefined) {
    return undefined;
  }

  const value = Number.parseInt(rawValue, 10);
  return Number.isInteger(value) ? value : undefined;
}
