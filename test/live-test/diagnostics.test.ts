import { describe, expect, it } from "vitest";
import { redactMediaTokens } from "../../scripts/live-test/diagnostics.ts";

describe("redactMediaTokens", () => {
  it("redacts the download token in a SceneGraph image uri", () => {
    const xml =
      '<Poster name="renderedImage" uri="https://api.put.io/v2/files/42/download?oauth_token=ABC123" />';

    expect(redactMediaTokens(xml)).toBe(
      '<Poster name="renderedImage" uri="https://api.put.io/v2/files/42/download?oauth_token=[redacted]" />',
    );
  });

  it("keeps the query parameters after the token", () => {
    expect(
      redactMediaTokens("/v2/files/42/hls/media.m3u8?oauth_token=ABC123&amp;subtitle_languages=en"),
    ).toBe("/v2/files/42/hls/media.m3u8?oauth_token=[redacted]&amp;subtitle_languages=en");
  });

  it("redacts tokens inside JSON-encoded debug command bodies", () => {
    const body = JSON.stringify({
      body: "texture https://api.put.io/v2/files/42/download?oauth_token=ABC123\nnext",
    });

    expect(redactMediaTokens(body)).not.toContain("ABC123");
  });
});
