export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

export type RetryOptions = {
  readonly attempts: number;
  readonly delayMs: number;
  readonly onRetry?: (error: unknown, attempt: number) => void | Promise<void>;
};

export async function retryAsync<T>(
  run: () => Promise<T>,
  options: RetryOptions,
): Promise<T> {
  if (!Number.isInteger(options.attempts) || options.attempts < 1) {
    throw new Error(`retryAsync attempts must be a positive integer, got ${options.attempts}`);
  }

  if (options.delayMs < 0) {
    throw new Error(`retryAsync delayMs must be non-negative, got ${options.delayMs}`);
  }

  let lastError: unknown;

  for (let attempt = 1; attempt <= options.attempts; attempt += 1) {
    try {
      return await run();
    } catch (error) {
      lastError = error;

      if (attempt === options.attempts) {
        break;
      }

      await options.onRetry?.(error, attempt);
      await sleep(options.delayMs);
    }
  }

  throw lastError;
}
