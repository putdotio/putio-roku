import {
  lstatSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseEnv } from "node:util";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  parseSecretPayload,
  renderSecretPayload,
  secretsSetup,
  type RokuSecretPayload,
} from "../../scripts/roku-task/secrets.ts";

const tempDirs: string[] = [];
const outputs: string[] = [];

const validPayload: RokuSecretPayload = {
  AUDIO_CONTENT_ID: "1",
  IMAGE_CONTENT_ID: "2",
  PLAYBACK_CONTENT_ID: "3",
  PUTIO_CLI_CONFIG_PATH: ".putio-cli/devs-fe-auto.json",
  PUTIO_CLI_PROFILE: "devs-fe-auto",
  PUTIO_CLIENT_ID_FIRST_PARTY: "4",
  PUTIO_CLIENT_SECRET_FIRST_PARTY: "client-secret",
  PUTIO_TEST_PASSWORD: "password",
  PUTIO_TEST_TOTP_REFERENCE: "reference",
  PUTIO_TEST_USERNAME: "username",
  ROKU_DEV_PASSWORD: "device-password",
  SUBTITLE_CONTENT_ID: "5",
};

afterEach(() => {
  vi.unstubAllEnvs();
  for (const output of outputs.splice(0)) {
    rmSync(output, { force: true });
  }
  for (const tempDir of tempDirs.splice(0)) {
    rmSync(tempDir, { force: true, recursive: true });
  }
});

describe("Roku SOPS payload", () => {
  it("parses the exact contract and renders a dotenv round trip", () => {
    const parsed = parseSecretPayload(JSON.stringify(validPayload));
    expect(parsed).toEqual(validPayload);
    expect(parseEnv(renderSecretPayload(parsed))).toEqual(validPayload);
  });

  it("rejects missing, extra, empty, non-string, wrapped, and malformed numeric values", () => {
    expect(() => parseSecretPayload(JSON.stringify(withoutKey(validPayload, "AUDIO_CONTENT_ID")))).toThrow(
      "key inventory does not match",
    );
    expect(() => parseSecretPayload(JSON.stringify({ ...validPayload, UNKNOWN: "value" }))).toThrow(
      "key inventory does not match",
    );
    expect(() => parseSecretPayload(JSON.stringify({ ...validPayload, PUTIO_TEST_PASSWORD: "" }))).toThrow(
      "must not be empty",
    );
    expect(() => parseSecretPayload(JSON.stringify({ ...validPayload, PUTIO_TEST_PASSWORD: 42 }))).toThrow(
      "must be a string",
    );
    expect(() => parseSecretPayload(JSON.stringify({ ...validPayload, PUTIO_TEST_PASSWORD: '"wrapped"' }))).toThrow(
      "must not be quote-wrapped",
    );
    expect(() => parseSecretPayload(JSON.stringify({ ...validPayload, AUDIO_CONTENT_ID: "not-numeric" }))).toThrow(
      "must contain decimal digits only",
    );
  });

  it("writes one ignored mode-0600 env file and removes its temporary directory", () => {
    const tempDir = makeTempDir();
    const ciphertext = join(tempDir, "roku.sops.env");
    writeFileSync(ciphertext, "ciphertext");
    const output = `.env.local.sops-test-${process.pid}-${Date.now()}`;
    outputs.push(output);
    vi.stubEnv("PUTIO_ROKU_SOPS_FILE", ciphertext);
    vi.stubEnv("SECRETS_OUTPUT", output);
    const before = rokuSecretTempDirs();

    secretsSetup((_input, decryptedOutput) => {
      writeFileSync(decryptedOutput, JSON.stringify(validPayload), { mode: 0o600 });
    });

    expect(parseEnv(readFileSync(output, "utf8"))).toEqual(validPayload);
    expect(lstatSync(output).mode & 0o777).toBe(0o600);
    expect(rokuSecretTempDirs()).toEqual(before);
  });

  it("installs to the validated normalized output path", () => {
    const tempDir = makeTempDir();
    const ciphertext = join(tempDir, "roku.sops.env");
    writeFileSync(ciphertext, "ciphertext");
    const output = `.env.local.sops-normalized-${process.pid}-${Date.now()}`;
    outputs.push(output);
    vi.stubEnv("PUTIO_ROKU_SOPS_FILE", ciphertext);
    vi.stubEnv("SECRETS_OUTPUT", `missing/../${output}`);

    secretsSetup((_input, decryptedOutput) => {
      writeFileSync(decryptedOutput, JSON.stringify(validPayload), { mode: 0o600 });
    });

    expect(parseEnv(readFileSync(output, "utf8"))).toEqual(validPayload);
  });

  it("rejects symlinked ciphertext and output paths", () => {
    const tempDir = makeTempDir();
    const ciphertext = join(tempDir, "roku.sops.env");
    const ciphertextLink = join(tempDir, "ciphertext-link");
    writeFileSync(ciphertext, "ciphertext");
    symlinkSync(ciphertext, ciphertextLink);
    vi.stubEnv("PUTIO_ROKU_SOPS_FILE", ciphertextLink);
    vi.stubEnv("SECRETS_OUTPUT", `.env.local.sops-test-${process.pid}-${Date.now()}`);

    expect(() => secretsSetup()).toThrow("ciphertext input must be one regular non-symlink file");

    const outputTarget = `.env.local.sops-target-${process.pid}-${Date.now()}`;
    const outputLink = `.env.local.sops-link-${process.pid}-${Date.now()}`;
    outputs.push(outputTarget, outputLink);
    writeFileSync(outputTarget, "target");
    symlinkSync(outputTarget, outputLink);
    vi.stubEnv("PUTIO_ROKU_SOPS_FILE", ciphertext);
    vi.stubEnv("SECRETS_OUTPUT", outputLink);

    expect(() => secretsSetup()).toThrow("SECRETS_OUTPUT must be one regular non-symlink file");
  });
});

function makeTempDir(): string {
  const tempDir = mkdtempSync(join(tmpdir(), "putio-roku-secrets-test-"));
  tempDirs.push(tempDir);
  return tempDir;
}

function rokuSecretTempDirs(): readonly string[] {
  return readdirSync(tmpdir())
    .filter((entry) => entry.startsWith("putio-roku-secrets-"))
    .sort();
}

function withoutKey(
  payload: RokuSecretPayload,
  omitted: keyof RokuSecretPayload,
): Record<string, string> {
  return Object.fromEntries(Object.entries(payload).filter(([key]) => key !== omitted));
}
