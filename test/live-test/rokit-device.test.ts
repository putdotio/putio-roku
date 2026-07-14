import { afterEach, describe, expect, it, vi } from "vitest";
import { configuredAppId, requireTarget } from "../../scripts/live-test/rokit-device.ts";

describe("Roku device configuration", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("defaults live-test launches to the sideloaded dev app", () => {
    vi.stubEnv("ROKU_APP_ECP_ID", "");

    expect(configuredAppId()).toBe("dev");
  });

  it("uses an explicit ECP app id for beta or public app launches", () => {
    vi.stubEnv("ROKU_APP_ECP_ID", "123456");

    expect(configuredAppId()).toBe("123456");
  });

  it("normalizes Roku target host values", () => {
    vi.stubEnv("ROKU_DEV_TARGET", "http://192.0.2.10:8060/query/device-info");

    expect(requireTarget()).toBe("192.0.2.10");
  });
});
