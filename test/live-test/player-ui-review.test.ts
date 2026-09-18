import { describe, expect, it } from "vitest";
import { readImageDimensions } from "../../scripts/live-test/player-ui-review.ts";

function webpContainer(chunk: string, payload: Buffer): Buffer {
  const header = Buffer.alloc(20);
  header.write("RIFF", 0, "ascii");
  header.writeUInt32LE(payload.length + 12, 4);
  header.write("WEBP", 8, "ascii");
  header.write(chunk, 12, "ascii");
  header.writeUInt32LE(payload.length, 16);
  return Buffer.concat([header, payload]);
}

describe("readImageDimensions", () => {
  it("reads lossy VP8 WebP dimensions", () => {
    const payload = Buffer.alloc(10);
    payload.set([0x9d, 0x01, 0x2a], 3);
    payload.writeUInt16LE(1920, 6);
    payload.writeUInt16LE(1080, 8);

    expect(readImageDimensions(webpContainer("VP8 ", payload))).toEqual({
      width: 1920,
      height: 1080,
    });
  });

  it("reads lossless VP8L WebP dimensions", () => {
    const payload = Buffer.alloc(5);
    payload[0] = 0x2f;
    payload.writeUInt32LE((1920 - 1) | ((1080 - 1) << 14), 1);

    expect(readImageDimensions(webpContainer("VP8L", payload))).toEqual({
      width: 1920,
      height: 1080,
    });
  });

  it("reads extended VP8X WebP canvas dimensions", () => {
    const payload = Buffer.alloc(10);
    payload.writeUIntLE(1920 - 1, 4, 3);
    payload.writeUIntLE(1080 - 1, 7, 3);

    expect(readImageDimensions(webpContainer("VP8X", payload))).toEqual({
      width: 1920,
      height: 1080,
    });
  });

  it("rejects a WebP container with an unknown first chunk", () => {
    expect(() => readImageDimensions(webpContainer("ALPH", Buffer.alloc(10)))).toThrow(
      /could not read WebP dimensions/,
    );
  });
});
