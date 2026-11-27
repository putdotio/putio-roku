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

  it("redacts a URL-encoded token inside another URL", () => {
    expect(
      redactMediaTokens(
        "next=https%3A%2F%2Fapi.put.io%2Fv2%2Ffiles%2F42%2Fdownload%3Foauth_token%3DABC123%26x%3D1",
      ),
    ).toBe(
      "next=https%3A%2F%2Fapi.put.io%2Fv2%2Ffiles%2F42%2Fdownload%3Foauth_token%3D[redacted]%26x%3D1",
    );
  });

  it("redacts token fields in SceneGraph attributes and JSON", () => {
    const text = [
      '<Auth name="auth" token="OAUTH123" />',
      JSON.stringify({ user: { download_token: "DL123" }, downloadToken: "DL456" }),
      JSON.stringify({ body: JSON.stringify({ oauth_token: "OAUTH456" }) }),
    ].join("\n");

    const redacted = redactMediaTokens(text);

    for (const secret of ["OAUTH123", "DL123", "DL456", "OAUTH456"]) {
      expect(redacted).not.toContain(secret);
    }
    expect(redacted).toContain('token="[redacted]"');
  });

  it("redacts the Authorization header token", () => {
    expect(redactMediaTokens("Authorization: token OAUTH123")).toBe(
      "Authorization: token [redacted]",
    );
  });
});
