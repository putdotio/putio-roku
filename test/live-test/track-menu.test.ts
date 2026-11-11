import { Writable } from "node:stream";
import { join } from "node:path";
import { execute } from "@rokucommunity/brs";
import { describe, expect, it } from "vitest";
import { trackMenuRowPoolSize } from "../../scripts/live-test/constants.ts";
import {
  playbackSpeedLabels,
  playbackSpeedMenuRow,
  trackMenuScrollOffset,
} from "../../scripts/live-test/track-menu.ts";
import { readRepoFile, repoRoot } from "./repo-files.ts";

function sink(): NodeJS.WriteStream {
  return new Writable({ write: (_chunk, _encoding, done) => done() }) as NodeJS.WriteStream;
}

async function readBrightScriptScrollOffsets(): Promise<number[][][]> {
  const files = [
    "components/shared/TrackMenu/TrackMenu.brs",
    "test/live-test/track-menu-scroll.brs",
  ].map((file) => join(repoRoot, file));
  const [output] = await execute(files, {
    root: repoRoot,
    componentDirs: [],
    stdout: sink(),
    stderr: sink(),
  });

  return JSON.parse(String(output)) as number[][][];
}

describe("TrackMenu live-test contract", () => {
  it("keeps the row pool size in step with TrackMenu", () => {
    const xmlRows = readRepoFile("components/shared/TrackMenu/TrackMenu.xml").match(
      /<Group id="trackMenuRow\d+"/g,
    );
    const brsRowCount = /m\.visibleRowCount = (\d+)/.exec(
      readRepoFile("components/shared/TrackMenu/TrackMenu.brs"),
    )?.[1];

    expect(xmlRows).toHaveLength(trackMenuRowPoolSize);
    expect(Number(brsRowCount)).toBe(trackMenuRowPoolSize);
  });

  it("scrolls exactly like TrackMenu.brs", async () => {
    const offsets = await readBrightScriptScrollOffsets();

    offsets.forEach((byItemCount, rowCount) => {
      byItemCount.forEach((byFocus, itemCount) => {
        byFocus.forEach((offset, focusedIndex) => {
          expect(
            trackMenuScrollOffset(itemCount, focusedIndex, rowCount),
            `rows=${rowCount} items=${itemCount} focus=${focusedIndex}`,
          ).toBe(offset);
        });
      });
    });
  });

  it("lists the speeds the player and the Lab story offer", () => {
    const playerOptions = /m\.playbackSpeedOptions = \[([^\]]*)\]/.exec(
      readRepoFile("components/screens/VideoPlayer/VideoPlayer.brs"),
    )?.[1];
    const labItems = /function getPlaybackSpeedMenuItems\(\)[\s\S]*?end function/.exec(
      readRepoFile("components/lab/Lab.brs"),
    )?.[0];

    expect(playerOptions?.split(",").map((speed) => `${Number(speed.trim())}x`)).toEqual(
      playbackSpeedLabels,
    );
    expect([...(labItems ?? "").matchAll(/label: "([^"]+)"/g)].map((match) => match[1])).toEqual(
      playbackSpeedLabels,
    );
  });

  it.each(playbackSpeedLabels)("finds the selected %s row inside the rendered pool", (label) => {
    const itemIndex = playbackSpeedLabels.indexOf(label);
    const rowCount = Math.min(playbackSpeedLabels.length, trackMenuRowPoolSize);

    expect(playbackSpeedMenuRow(label)).toBe(
      itemIndex - trackMenuScrollOffset(playbackSpeedLabels.length, itemIndex, rowCount),
    );
    expect(playbackSpeedMenuRow(label)).toBeLessThan(trackMenuRowPoolSize);
  });
});
