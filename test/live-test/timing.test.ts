import { describe, expect, it } from "vitest";
import { retryAsync } from "../../scripts/live-test/timing.ts";

describe("retryAsync", () => {
  it("returns the first successful attempt", async () => {
    let attempts = 0;

    await expect(
      retryAsync(
        async () => {
          attempts += 1;
          if (attempts < 3) {
            throw new Error(`attempt ${attempts}`);
          }

          return "ok";
        },
        { attempts: 4, delayMs: 0 },
      ),
    ).resolves.toBe("ok");

    expect(attempts).toBe(3);
  });

  it("reports retryable failures before the final error", async () => {
    const retryMessages: string[] = [];

    await expect(
      retryAsync(
        async () => {
          throw new Error("still down");
        },
        {
          attempts: 3,
          delayMs: 0,
          onRetry: (error, attempt) => {
            retryMessages.push(`${attempt}:${error instanceof Error ? error.message : String(error)}`);
          },
        },
      ),
    ).rejects.toThrow("still down");

    expect(retryMessages).toEqual(["1:still down", "2:still down"]);
  });

  it("rejects invalid retry options before running", async () => {
    let didRun = false;

    await expect(
      retryAsync(
        async () => {
          didRun = true;
          return "ok";
        },
        { attempts: 0, delayMs: 0 },
      ),
    ).rejects.toThrow("attempts must be a positive integer");

    expect(didRun).toBe(false);
  });
});
