import { readFile } from "node:fs/promises";
import { join } from "node:path";
import process from "node:process";
import { setTimeout as delay } from "node:timers/promises";

type PutioCliAuthProfile = {
  readonly auth_token?: string;
};

type PutioCliConfig = {
  readonly auth_token?: string;
  readonly profiles?: Record<string, PutioCliAuthProfile>;
};

export function putioProfileFromArg(rawProfile?: string): string {
  return rawProfile?.trim() || process.env.PUTIO_CLI_PROFILE?.trim() || "devs-fe-auto";
}

export async function setPlaybackTypeConfig(
  playbackType: "hls" | "mp4",
  profile?: string,
): Promise<void> {
  const resolvedProfile = putioProfileFromArg(profile);
  await setPutioConfigValue(resolvedProfile, "playbackType", playbackType);
  console.log(`set playbackType=${playbackType} for profile=${resolvedProfile}`);
}

function putioConfigPathForProfile(profile: string): string {
  const rawPath = process.env.PUTIO_CLI_CONFIG_PATH?.trim();

  if (rawPath) {
    return rawPath;
  }

  return join(process.cwd(), ".putio-cli", `${profile}.json`);
}

function putioApiBaseUrl(): string {
  return process.env.PUTIO_CLI_API_BASE_URL?.trim() || "https://api.put.io";
}

function parseJsonText(text: string, context: string): unknown {
  try {
    const value: unknown = JSON.parse(text);
    return value;
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown JSON parse error";
    throw new Error(`Could not parse JSON from ${context}: ${message}`);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function optionalString(record: Record<string, unknown>, key: string): string | undefined {
  const value = record[key];
  return typeof value === "string" ? value : undefined;
}

function parsePutioCliConfig(value: unknown): PutioCliConfig {
  if (!isRecord(value)) {
    throw new Error("Expected put.io CLI config to be an object");
  }

  const rawProfiles = value.profiles;
  const profiles: Record<string, PutioCliAuthProfile> = {};

  if (isRecord(rawProfiles)) {
    for (const [profile, rawProfile] of Object.entries(rawProfiles)) {
      if (!isRecord(rawProfile)) {
        continue;
      }

      const authToken = optionalString(rawProfile, "auth_token");
      if (authToken !== undefined) {
        profiles[profile] = { auth_token: authToken };
      }
    }
  }

  return {
    auth_token: optionalString(value, "auth_token"),
    profiles: Object.keys(profiles).length === 0 ? undefined : profiles,
  };
}

async function readPreparedPutioToken(profile: string): Promise<string> {
  const configPath = putioConfigPathForProfile(profile);
  const config = parsePutioCliConfig(parseJsonText(await readFile(configPath, "utf8"), configPath));
  const token = config.profiles?.[profile]?.auth_token ?? config.auth_token;

  if (!token) {
    throw new Error(`No put.io token is configured for ${profile}. Run auth-prepare first.`);
  }

  return token;
}

async function setPutioConfigValue(profile: string, key: string, value: string): Promise<void> {
  const token = await readPreparedPutioToken(profile);
  const url = new URL(`/v2/config/${encodeURIComponent(key)}`, putioApiBaseUrl());
  const response = await fetch(url, {
    method: "PUT",
    headers: {
      Authorization: `token ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ value }),
  });

  if (!response.ok) {
    throw new Error(`put.io config update failed (${response.status}): ${await response.text()}`);
  }

  const startedAt = Date.now();
  let lastValue = "unset";

  while (Date.now() - startedAt < 10_000) {
    const currentValue = await readPutioConfigValue(token, key);
    lastValue = currentValue ?? "missing";

    if (currentValue === value) {
      return;
    }

    await delay(500);
  }

  throw new Error(`put.io config ${key} did not settle to ${value}; last value was ${lastValue}`);
}

async function readPutioConfigValue(token: string, key: string): Promise<string | undefined> {
  const response = await fetch(new URL("/v2/config", putioApiBaseUrl()), {
    headers: {
      Authorization: `token ${token}`,
    },
  });

  if (!response.ok) {
    throw new Error(`put.io config read failed (${response.status}): ${await response.text()}`);
  }

  const data = parseJsonText(await response.text(), "put.io config response");
  if (!isRecord(data) || !isRecord(data.config)) {
    return undefined;
  }

  return optionalString(data.config, key);
}
