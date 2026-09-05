import { beforeEach, describe, expect, it, vi } from "vitest";
import { runAppFlow, type AppFlowDriver } from "../../scripts/live-test/app-flows.ts";

const device = vi.hoisted(() => ({
  folder: "Your Files",
  focus: 2,
  focusAttribute: "focusItem",
  selectWorks: true,
  backWorks: true,
  restoreFocus: true,
  keys: [] as string[],
}));

function snapshot(): string {
  const focus = device.focusAttribute ? `${device.focusAttribute}="${device.focus}"` : "";
  return `<Scene><SearchScreen visible="false"><Label name="titleLabel" text="Fixture folder" /></SearchScreen><FilesScreen name="filesScreen" visible="true"><ScreenHeader><Label name="titleLabel" text="${device.folder}" /></ScreenHeader><LoadingIndicator name="loading" visible="false" /><MarkupList name="fileList" visible="true" ${focus} count="4" /></FilesScreen></Scene>`;
}

vi.mock("../../scripts/live-test/rokit-device.ts", () => ({
  querySceneGraph: async () => snapshot(),
  pressKey: async (_target: string, key: string) => {
    device.keys.push(key);
    if (key === "Select" && device.selectWorks) {
      device.folder = "Fixture folder";
      device.focus = 0;
    }
    if (key === "Back" && device.backWorks) {
      device.folder = "Your Files";
      device.focus = device.restoreFocus ? 2 : 0;
    }
  },
  waitForSceneGraphAssertion: async (_target: string, _message: string, assert: (xml: string) => void) => {
    assert(snapshot());
  },
}));

const noop = async () => {};
const driver: AppFlowDriver = {
  assertListHasItems: async () => 4,
  authRefreshSmoke: noop,
  focusLastListItem: noop,
  focusListItemByIndex: async (_target, _nodeName, index) => { device.focus = index; },
  openHomeItem: noop,
  playbackTypeSmoke: noop,
  imageRenderSmoke: noop,
  playerUiSmoke: noop,
  resetAuthState: noop,
  returnToHomeScreen: noop,
  waitForAnyRouteScreenVisible: async () => "filesScreen",
  waitForAuthReady: noop,
  waitForBootstrapScreen: async () => "filesScreen",
  waitForRouteScreenVisible: noop,
};
const options = { profile: "synthetic", mediaType: "movie", startFromChoice: "continue", filesFolderName: "Fixture folder", filesFolderIndex: 2 } as const;
const run = () => runAppFlow("files", { target: "synthetic", artifactDir: "unused" }, options, driver);

describe("Files navigation proof", () => {
  beforeEach(() => {
    Object.assign(device, { folder: "Your Files", focus: 2, focusAttribute: "focusItem", selectWorks: true, backWorks: true, restoreFocus: true, keys: [] });
  });

  it("requires a prepared fixture before sending keys", async () => {
    await expect(runAppFlow("files", { target: "synthetic", artifactDir: "unused" }, { profile: "synthetic", mediaType: "movie", startFromChoice: "continue" }, driver)).rejects.toThrow("FILES_FOLDER_NAME");
    expect(device.keys).toEqual([]);
  });

  it("passes only after the selected folder opens and Back restores parent and focus", async () => {
    await run();
    expect(device.keys).toEqual(["Select", "Back"]);
  });

  it("rejects no-op Select even when Files remains visible and a hidden screen has the destination title", async () => {
    device.selectWorks = false;
    await expect(run()).rejects.toThrow();
    expect(device.keys).toEqual(["Select"]);
  });

  it("accepts the inspector's itemFocused field", async () => {
    device.focusAttribute = "itemFocused";
    await run();
    expect(device.keys).toEqual(["Select", "Back"]);
  });

  it("rejects missing focus evidence even for fixture index zero", async () => {
    device.focusAttribute = "";
    await expect(runAppFlow("files", { target: "synthetic", artifactDir: "unused" }, { ...options, filesFolderIndex: 0 }, driver)).rejects.toThrow();
    expect(device.keys).toEqual([]);
  });

  it("rejects no-op Back", async () => {
    device.backWorks = false;
    await expect(run()).rejects.toThrow();
  });

  it("rejects Back that restores the parent but loses selection", async () => {
    device.restoreFocus = false;
    await expect(run()).rejects.toThrow("fixture row");
  });
});
