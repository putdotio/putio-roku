import { access, copyFile, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { extname, join } from "node:path";
import process from "node:process";

type StartFromChoice = "continue" | "beginning";

type PlaybackLaunchResult = {
  readonly id: string;
  readonly name: string;
  readonly version: string;
};

type PlayerUiReviewContext = {
  readonly target: string;
  readonly audioContentId: string;
  readonly subtitleContentId: string;
  readonly mediaType: string;
  readonly startFromChoice: StartFromChoice;
};

type ImageMetadata = {
  readonly filename: string;
  readonly width: number;
  readonly height: number;
};

type ReviewImage = {
  readonly alt: string;
  readonly filename: string;
  readonly title: string;
};

export type PlayerUiScreenshotDriver = {
  readonly launchPlaybackWithRemoteStart: (
    contentId: string,
    mediaType: string,
    startFromChoice: StartFromChoice,
  ) => Promise<PlaybackLaunchResult>;
  readonly waitForPlayerClockReady: () => Promise<void>;
  readonly assertDirectPlaybackSurfaceOnDevice: (contentId: string) => Promise<void>;
  readonly pausePlaybackForStableOsd: () => Promise<void>;
  readonly focusInitialControlsForScreenshot: () => Promise<void>;
  readonly isSpeedControlAvailable: () => Promise<boolean>;
  readonly focusSpeedButtonFromPlayback: () => Promise<void>;
  readonly openSpeedMenuFromPlayback: () => Promise<void>;
  readonly isAudioControlAvailable: () => Promise<boolean>;
  readonly focusAudioButtonFromPlayback: () => Promise<void>;
  readonly assertFocusRoundTrip: (focusLabelId: string) => Promise<void>;
  readonly openAudioMenuFromPlayback: () => Promise<void>;
  readonly focusSubtitleButtonFromPlayback: () => Promise<void>;
  readonly openSubtitleMenuFromPlayback: () => Promise<void>;
  readonly focusProgressFromOpenMenu: () => Promise<void>;
  readonly assertProgressFocused: () => Promise<void>;
  readonly pressKey: (key: string) => Promise<void>;
  readonly sleep: (ms: number) => Promise<void>;
  readonly captureScreenshot: (outputPath: string) => Promise<string>;
};

export async function capturePlayerUiScreenshots(
  driver: PlayerUiScreenshotDriver,
  context: PlayerUiReviewContext,
  outputDir: string,
): Promise<void> {
  await cleanupPlayerUiReviewArtifacts(outputDir);

  const audioApp = await driver.launchPlaybackWithRemoteStart(
    context.audioContentId,
    context.mediaType,
    context.startFromChoice,
  );
  console.log(
    `opened audio playback: ${audioApp.id} ${audioApp.name} ${audioApp.version} contentID=${context.audioContentId}`,
  );
  await driver.waitForPlayerClockReady();
  await driver.assertDirectPlaybackSurfaceOnDevice(context.audioContentId);
  await driver.pausePlaybackForStableOsd();
  await driver.focusInitialControlsForScreenshot();
  const playFocusPath = await driver.captureScreenshot(join(outputDir, "play-focus.jpg"));
  console.log(`captured initial controls screenshot: ${playFocusPath}`);

  if (await driver.isSpeedControlAvailable()) {
    await driver.focusSpeedButtonFromPlayback();
    const speedButtonPath = await driver.captureScreenshot(
      join(outputDir, "speed-button-focus.jpg"),
    );
    console.log(`captured speed button focus screenshot: ${speedButtonPath}`);
    await driver.openSpeedMenuFromPlayback();
    const speedPath = await driver.captureScreenshot(join(outputDir, "speed-menu.jpg"));
    console.log(`captured speed menu screenshot: ${speedPath}`);
    await driver.pressKey("Select");
    await driver.sleep(750);
  } else {
    console.log("skipped speed screenshots: Roku Video.playbackSpeed is unavailable");
  }

  if (await driver.isAudioControlAvailable()) {
    await driver.focusAudioButtonFromPlayback();
    await driver.assertFocusRoundTrip("audioFocusLabel");
    const audioButtonPath = await driver.captureScreenshot(
      join(outputDir, "audio-button-focus.jpg"),
    );
    console.log(`captured audio button focus screenshot: ${audioButtonPath}`);
    await driver.openAudioMenuFromPlayback();
    const audioPath = await driver.captureScreenshot(join(outputDir, "audio-menu.jpg"));
    console.log(`captured audio menu screenshot: ${audioPath}`);
    await driver.pressKey("Select");
    await driver.sleep(750);
  } else {
    console.log("skipped audio screenshots: Roku did not expose multiple audio tracks");
  }

  const subtitleApp = await driver.launchPlaybackWithRemoteStart(
    context.subtitleContentId,
    context.mediaType,
    context.startFromChoice,
  );
  console.log(
    `opened subtitle playback: ${subtitleApp.id} ${subtitleApp.name} ${subtitleApp.version} contentID=${context.subtitleContentId}`,
  );
  await driver.waitForPlayerClockReady();
  await driver.assertDirectPlaybackSurfaceOnDevice(context.subtitleContentId);
  await driver.pausePlaybackForStableOsd();
  await driver.focusSubtitleButtonFromPlayback();
  await driver.assertFocusRoundTrip("captionsFocusLabel");
  const subtitleButtonPath = await driver.captureScreenshot(
    join(outputDir, "subtitle-button-focus.jpg"),
  );
  console.log(`captured subtitle button focus screenshot: ${subtitleButtonPath}`);
  await driver.openSubtitleMenuFromPlayback();
  const subtitlePath = await driver.captureScreenshot(join(outputDir, "subtitle-menu.jpg"));
  console.log(`captured subtitle menu screenshot: ${subtitlePath}`);

  await driver.focusProgressFromOpenMenu();
  await driver.assertProgressFocused();
  const progressPath = await driver.captureScreenshot(join(outputDir, "progress-focus.jpg"));
  console.log(`captured progress focus screenshot: ${progressPath}`);

  const reviewPath = await writePlayerUiReview(outputDir, context);
  console.log(`wrote player UI review: ${reviewPath}`);
}

async function cleanupPlayerUiReviewArtifacts(outputDir: string): Promise<void> {
  await mkdir(outputDir, { recursive: true });

  await Promise.all(
    [
      "audio-button-focus.jpg",
      "audio-menu.jpg",
      "play-focus.jpg",
      "progress-focus.jpg",
      "progress-focus-latest.jpg",
      "reference-tv-native.jpg",
      "reference-tv-native.jpeg",
      "reference-tv-native.png",
      "reference-tv-native.webp",
      "reference-tv-native-audio-focus.png",
      "reference-tv-native-audio-menu.png",
      "reference-tv-native-controls.png",
      "reference-tv-native-progress.png",
      "reference-tv-native-speed-menu.png",
      "reference-tv-native-subtitle-menu.png",
      "review.html",
      "speed-button-focus.jpg",
      "speed-menu.jpg",
      "subtitle-button-focus.jpg",
      "subtitle-menu.jpg",
    ].map(async (filename) => {
      await rm(join(outputDir, filename), { force: true });
    }),
  );
}

async function writePlayerUiReview(
  outputDir: string,
  context: PlayerUiReviewContext,
): Promise<string> {
  const referenceImages = await copyPlayerUiReferenceImages(outputDir);
  const hasAudioMenu = await fileExists(join(outputDir, "audio-menu.jpg"));
  const hasAudioButton = await fileExists(join(outputDir, "audio-button-focus.jpg"));
  const hasSpeedMenu = await fileExists(join(outputDir, "speed-menu.jpg"));
  const hasSpeedButton = await fileExists(join(outputDir, "speed-button-focus.jpg"));
  const imageMetadata = await readPlayerUiImageMetadata(outputDir, [
    "audio-button-focus.jpg",
    "audio-menu.jpg",
    "play-focus.jpg",
    "progress-focus.jpg",
    "speed-button-focus.jpg",
    "speed-menu.jpg",
    "subtitle-button-focus.jpg",
    "subtitle-menu.jpg",
    ...referenceImages.map((image) => image.filename),
  ]);
  const reviewPath = join(outputDir, "review.html");
  const generatedAt = new Date().toISOString();
  const smokeCommand = `AUDIO_CONTENT_ID=${context.audioContentId} SUBTITLE_CONTENT_ID=${context.subtitleContentId} MEDIA_TYPE=${context.mediaType} START_FROM=${context.startFromChoice} pnpm roku live-test-player-ui`;
  const screenshotCommand = `AUDIO_CONTENT_ID=${context.audioContentId} SUBTITLE_CONTENT_ID=${context.subtitleContentId} MEDIA_TYPE=${context.mediaType} START_FROM=${context.startFromChoice} pnpm roku live-test-player-ui-screenshots`;
  const nativeCapturePanels = referenceImages
    .map(
      (image) => `
      <section class="panel wide">
        <h2>${escapeHtml(image.title)}</h2>
        <img src="./${escapeHtml(image.filename)}" alt="${escapeHtml(image.alt)}" />
      </section>`,
    )
    .join("");
  const speedMenuPanel = hasSpeedMenu
    ? `
      <section class="panel">
        <h2>Speed menu</h2>
        <img src="./speed-menu.jpg" alt="Roku speed menu" />
      </section>`
    : "";
  const speedButtonPanel = hasSpeedButton
    ? `
      <section class="panel">
        <h2>Speed button focus</h2>
        <img src="./speed-button-focus.jpg" alt="Roku speed button focus" />
      </section>`
    : "";
  const speedChecklistItem = hasSpeedMenu
    ? "<li>Playback speed menu captured and covered by live smoke selection.</li>"
    : "<li>Playback speed menu was skipped because this Roku did not expose Video.playbackSpeed.</li>";
  const audioChecklistItem = hasAudioMenu
    ? "<li>Audio and subtitle menus open from player controls and move selected checkmarks.</li>"
    : "<li>Subtitle menu opens from player controls; audio menu was skipped because Roku did not expose multiple audio tracks.</li>";
  const audioMenuPanel = hasAudioMenu
    ? `
      <section class="panel">
        <h2>Audio menu</h2>
        <img src="./audio-menu.jpg" alt="Roku audio menu" />
      </section>`
    : "";
  const audioButtonPanel = hasAudioButton
    ? `
      <section class="panel">
        <h2>Audio button focus</h2>
        <img src="./audio-button-focus.jpg" alt="Roku audio button focus" />
      </section>`
    : "";
  const imageMetadataItems = imageMetadata
    .map(
      (metadata) =>
        `<li><code>${escapeHtml(metadata.filename)}</code> ${metadata.width}×${metadata.height}</li>`,
    )
    .join("");

  await writeFile(
    reviewPath,
    `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Roku Player UI Review</title>
    <style>
      :root {
        background: #000000;
        color: #ededed;
        color-scheme: dark;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }

      body {
        margin: 0;
        padding: 28px;
      }

      h1,
      h2 {
        margin: 0;
        font-weight: 650;
      }

      h1 {
        font-size: 24px;
      }

      .meta {
        color: #a0a0a0;
        display: grid;
        gap: 6px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        margin-top: 14px;
      }

      .meta div {
        background: #161616;
        border: 1px solid #343434;
        padding: 10px 12px;
      }

      .meta strong {
        color: #ededed;
        display: block;
        font-size: 12px;
        margin-bottom: 3px;
      }

      .checklist {
        background: #161616;
        border: 1px solid #343434;
        color: #ededed;
        margin-top: 18px;
        padding: 14px 16px;
      }

      .checklist ul {
        display: grid;
        gap: 8px 18px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        list-style: none;
        margin: 0;
        padding: 0;
      }

      .checklist li::before {
        color: #fdce45;
        content: "✓";
        margin-right: 8px;
      }

      .captures {
        background: #161616;
        border: 1px solid #343434;
        color: #a0a0a0;
        margin-top: 10px;
        padding: 12px 16px;
      }

      .captures ul {
        display: grid;
        gap: 6px 18px;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        list-style: none;
        margin: 0;
        padding: 0;
      }

      code {
        color: #ededed;
        font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
        font-size: 12px;
        overflow-wrap: anywhere;
      }

      h2 {
        color: #a0a0a0;
        font-size: 15px;
        margin-bottom: 10px;
      }

      .grid {
        display: grid;
        gap: 24px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        margin-top: 24px;
      }

      .panel {
        background: #161616;
        border: 1px solid #343434;
        padding: 14px;
      }

      .wide {
        grid-column: 1 / -1;
      }

      img {
        background: #000000;
        display: block;
        height: auto;
        width: 100%;
      }

    </style>
  </head>
  <body>
    <h1>Roku Player UI Review</h1>
    <div class="meta">
      <div><strong>Target</strong><code>${escapeHtml(context.target)}</code></div>
      <div><strong>Start mode</strong><code>${escapeHtml(context.startFromChoice)}</code></div>
      <div><strong>Audio file</strong><code>${escapeHtml(context.audioContentId)}</code></div>
      <div><strong>Subtitle file</strong><code>${escapeHtml(context.subtitleContentId)}</code></div>
      <div><strong>Generated at</strong><code>${escapeHtml(generatedAt)}</code></div>
      <div><strong>Smoke proof</strong><code>${escapeHtml(smokeCommand)}</code></div>
      <div><strong>Screenshot proof</strong><code>${escapeHtml(screenshotCommand)}</code></div>
    </div>
    <section class="checklist" aria-label="Player UI proof checklist">
      <ul>
        <li>Direct player routing asserted; old play/subtitle preselection surface rejected.</li>
        ${audioChecklistItem}
        ${speedChecklistItem}
        <li>Progress focus and adaptive right-side option labels have SceneGraph geometry assertions.</li>
        <li>OSD auto-hide/reveal flow is covered by live smoke.</li>
        <li>Remote Play, Fast Forward, and Rewind keys are covered by live smoke.</li>
      </ul>
    </section>
    <section class="captures" aria-label="Captured image metadata">
      <ul>${imageMetadataItems}</ul>
    </section>
    <div class="grid">${nativeCapturePanels}${audioMenuPanel}
      <section class="panel">
        <h2>Subtitle menu</h2>
        <img src="./subtitle-menu.jpg" alt="Roku subtitle menu" />
      </section>${speedMenuPanel}${audioButtonPanel}
      <section class="panel">
        <h2>Subtitle button focus</h2>
        <img src="./subtitle-button-focus.jpg" alt="Roku subtitle button focus" />
      </section>${speedButtonPanel}
      <section class="panel">
        <h2>Initial controls</h2>
        <img src="./play-focus.jpg" alt="Roku initial controls" />
      </section>
      <section class="panel">
        <h2>Progress focus</h2>
        <img src="./progress-focus.jpg" alt="Roku progress focus" />
      </section>
    </div>
  </body>
</html>
`,
  );

  return reviewPath;
}

async function readPlayerUiImageMetadata(
  outputDir: string,
  filenames: string[],
): Promise<ImageMetadata[]> {
  const metadata: ImageMetadata[] = [];

  for (const filename of filenames) {
    if (!(await fileExists(join(outputDir, filename)))) {
      continue;
    }

    const dimensions = readImageDimensions(await readFile(join(outputDir, filename)));
    metadata.push({
      filename,
      width: dimensions.width,
      height: dimensions.height,
    });
  }

  return metadata;
}

function readImageDimensions(buffer: Buffer): { width: number; height: number } {
  const pngSignature = "89504e470d0a1a0a";
  if (buffer.subarray(0, 8).toString("hex") === pngSignature) {
    return {
      width: buffer.readUInt32BE(16),
      height: buffer.readUInt32BE(20),
    };
  }

  if (buffer[0] === 0xff && buffer[1] === 0xd8) {
    return readJpegDimensions(buffer);
  }

  throw new Error("unsupported image format in player UI review artifact");
}

function readJpegDimensions(buffer: Buffer): { width: number; height: number } {
  let offset = 2;

  while (offset + 9 < buffer.length) {
    if (buffer[offset] !== 0xff) {
      offset += 1;
      continue;
    }

    const marker = buffer[offset + 1];
    const segmentLength = buffer.readUInt16BE(offset + 2);
    const isStartOfFrame =
      marker >= 0xc0 &&
      marker <= 0xcf &&
      marker !== 0xc4 &&
      marker !== 0xc8 &&
      marker !== 0xcc;

    if (isStartOfFrame) {
      return {
        height: buffer.readUInt16BE(offset + 5),
        width: buffer.readUInt16BE(offset + 7),
      };
    }

    offset += 2 + segmentLength;
  }

  throw new Error("could not read JPEG dimensions in player UI review artifact");
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function copyOptionalReferenceImage(outputDir: string): Promise<string | undefined> {
  const referenceImage = process.env.PLAYER_UI_REFERENCE_IMAGE;

  if (!referenceImage) {
    return undefined;
  }

  await access(referenceImage);
  const extension = extname(referenceImage) || ".png";
  const filename = `reference-tv-native${extension}`;
  await copyFile(referenceImage, join(outputDir, filename));

  return filename;
}

async function copyPlayerUiReferenceImages(outputDir: string): Promise<ReviewImage[]> {
  const referenceImages: ReviewImage[] = [];
  const optionalReferenceImage = await copyOptionalReferenceImage(outputDir);

  if (optionalReferenceImage !== undefined) {
    referenceImages.push({
      alt: "Custom player UI reference capture",
      filename: optionalReferenceImage,
      title: "Custom reference",
    });
  }

  const referenceDir =
    process.env.PLAYER_UI_TV_NATIVE_REFERENCE_DIR ??
    join(
      process.cwd(),
      "..",
      "putio-frontend-workspace",
      "docs",
      "specs",
      "tv-native",
      "android-tv",
    );
  const references: Array<ReviewImage & { source: string }> = [
    {
      alt: "tv-native Android player controls",
      filename: "reference-tv-native-controls.png",
      source: "18-video-controls.png",
      title: "tv-native controls reference",
    },
    {
      alt: "tv-native Android language button focus",
      filename: "reference-tv-native-audio-focus.png",
      source: "30-video-multi-audio-language-focus.png",
      title: "tv-native language focus reference",
    },
    {
      alt: "tv-native Android audio track picker",
      filename: "reference-tv-native-audio-menu.png",
      source: "31-video-language-picker.png",
      title: "tv-native audio menu reference",
    },
    {
      alt: "tv-native Android subtitle picker",
      filename: "reference-tv-native-subtitle-menu.png",
      source: "21-video-subtitles-picker.png",
      title: "tv-native subtitle menu reference",
    },
    {
      alt: "tv-native Android speed picker",
      filename: "reference-tv-native-speed-menu.png",
      source: "20-video-speed-picker.png",
      title: "tv-native speed menu reference",
    },
    {
      alt: "tv-native Android focused seek bar",
      filename: "reference-tv-native-progress.png",
      source: "28-video-seekbar-focused.png",
      title: "tv-native progress focus reference",
    },
  ];

  for (const reference of references) {
    const sourcePath = join(referenceDir, reference.source);
    if (!(await fileExists(sourcePath))) {
      continue;
    }

    await copyFile(sourcePath, join(outputDir, reference.filename));
    referenceImages.push({
      alt: reference.alt,
      filename: reference.filename,
      title: reference.title,
    });
  }

  return referenceImages;
}
