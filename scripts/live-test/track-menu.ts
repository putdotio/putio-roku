import { trackMenuRowPoolSize } from "./constants.ts";

export const playbackSpeedLabels: readonly string[] = [
  "0.25x",
  "0.5x",
  "0.75x",
  "1x",
  "1.25x",
  "1.5x",
  "1.75x",
  "2x",
  "2.5x",
  "3x",
  "3.5x",
  "4x",
];

// Mirrors getTrackMenuScrollOffset in TrackMenu.brs; track-menu.test.ts runs both.
export function trackMenuScrollOffset(
  itemCount: number,
  focusedIndex: number,
  rowCount: number,
): number {
  if (itemCount <= rowCount) {
    return 0;
  }

  return Math.min(Math.max(focusedIndex - rowCount + 1, 0), itemCount - rowCount);
}

// TrackMenu opens focused on the selected item, so a selection past the pool sits on a scrolled row.
export function playbackSpeedMenuRow(label: string): number {
  const itemIndex = playbackSpeedLabels.indexOf(label);
  if (itemIndex === -1) {
    throw new Error(`unknown playback speed label "${label}"`);
  }

  const itemCount = playbackSpeedLabels.length;
  const rowCount = Math.min(itemCount, trackMenuRowPoolSize);

  return itemIndex - trackMenuScrollOffset(itemCount, itemIndex, rowCount);
}
