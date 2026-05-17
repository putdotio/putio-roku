import type { ActiveApp } from "@putdotio/rokit";

type PlaybackLaunchRetryOptions = {
  readonly afterLaunch?: () => Promise<void>;
  readonly formatError: (error: unknown) => string;
  readonly initialApp: ActiveApp;
  readonly initialLastLaunchAtMs?: number;
  readonly initialState: string;
  readonly launch: () => Promise<ActiveApp>;
  readonly launchLabel: string;
  readonly maxAttempts: number;
  readonly onRetry?: () => void;
  readonly retryDelayMs: number;
};

export type PlaybackLaunchRetry = {
  readonly app: ActiveApp;
  readonly lastState: string;
  maybeRetry: (reason: string) => Promise<boolean>;
  setLastState: (state: string) => void;
};

export const createPlaybackLaunchRetry = (
  options: PlaybackLaunchRetryOptions,
): PlaybackLaunchRetry => {
  let app = options.initialApp;
  let launchAttempts = 1;
  let lastLaunchAt = options.initialLastLaunchAtMs ?? 0;
  let lastState = options.initialState;

  return {
    get app() {
      return app;
    },
    get lastState() {
      return lastState;
    },
    async maybeRetry(reason: string): Promise<boolean> {
      if (
        launchAttempts >= options.maxAttempts ||
        Date.now() - lastLaunchAt < options.retryDelayMs
      ) {
        return false;
      }

      launchAttempts += 1;
      lastLaunchAt = Date.now();
      options.onRetry?.();
      lastState = `retrying ${options.launchLabel} after ${reason}`;

      try {
        app = await options.launch();
      } catch (error) {
        lastState = `${options.launchLabel} retry failed after ${reason}: ${options.formatError(error)}`;
      }

      await options.afterLaunch?.();
      return true;
    },
    setLastState(state: string): void {
      lastState = state;
    },
  };
};
