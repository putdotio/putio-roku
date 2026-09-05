import process from "node:process";
import { putioProfileFromArg } from "./putio-config.ts";

export type StartFromChoice = "continue" | "beginning";

export type AppFlowOptions = {
  readonly profile: string;
  readonly filesFolderName?: string;
  readonly filesFolderIndex?: number;
  readonly playbackContentId?: string;
  readonly imageContentId?: string;
  readonly audioContentId?: string;
  readonly subtitleContentId?: string;
  readonly historyExpectedText?: string;
  readonly mediaType: string;
  readonly startFromChoice: StartFromChoice;
};

export function appFlowOptionsFromArgs(args: readonly string[]): AppFlowOptions {
  const [
    rawPlaybackContentId = process.env.PLAYBACK_CONTENT_ID,
    rawAudioContentId = process.env.AUDIO_CONTENT_ID,
    rawSubtitleContentId = process.env.SUBTITLE_CONTENT_ID,
    mediaType = process.env.MEDIA_TYPE ?? "movie",
    rawStartFromChoice = process.env.START_FROM ?? "continue",
  ] = args;

  return {
    profile: putioProfileFromArg(),
    filesFolderName: emptyStringAsUndefined(process.env.FILES_FOLDER_NAME),
    filesFolderIndex: filesFolderIndexFromEnv(process.env.FILES_FOLDER_INDEX),
    playbackContentId: emptyStringAsUndefined(rawPlaybackContentId),
    imageContentId: emptyStringAsUndefined(process.env.IMAGE_CONTENT_ID),
    audioContentId: emptyStringAsUndefined(rawAudioContentId),
    subtitleContentId: emptyStringAsUndefined(rawSubtitleContentId),
    historyExpectedText: emptyStringAsUndefined(process.env.HISTORY_EXPECTED_TEXT),
    mediaType,
    startFromChoice: startFromChoiceFromArg(rawStartFromChoice),
  };
}

export function startFromChoiceFromArg(value: string): StartFromChoice {
  if (value === "continue" || value === "beginning") {
    return value;
  }

  throw new Error("start-from choice must be continue or beginning");
}

export function emptyStringAsUndefined(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed === undefined || trimmed === "" ? undefined : trimmed;
}

function filesFolderIndexFromEnv(value: string | undefined): number | undefined {
  const input = emptyStringAsUndefined(value);
  if (input === undefined) return undefined;
  const index = Number(input);
  if (!/^\d+$/u.test(input) || !Number.isSafeInteger(index)) {
    throw new Error("FILES_FOLDER_INDEX must be a non-negative integer");
  }
  return index;
}
