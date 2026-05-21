#!/usr/bin/env node
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, join } from "node:path";
import process from "node:process";
import { promisify } from "node:util";
import { execFile as execFileCallback } from "node:child_process";

const execFile = promisify(execFileCallback);

const defaultProfile = "devs-fe-auto";
const defaultAccountItem = "putio-test-account";
const defaultOAuthItem = "putio-oauth-first-party";
const defaultApiBaseUrl = "https://api.put.io";

type AuthStatus = {
  authenticated: boolean;
  source: string | null;
  apiBaseUrl: string;
  configPath: string;
  profile?: string;
};

type PutioDescribe = {
  auth?: {
    profileEnv?: string;
  };
  commands?: ReadonlyArray<{
    command: string;
    input?: {
      flags?: ReadonlyArray<{
        name: string;
      }>;
    };
  }>;
};

type PutioConfig = {
  api_base_url: string;
  auth_token?: string;
  default_profile?: string;
  profiles?: Record<
    string,
    {
      api_base_url: string;
      auth_token: string;
    }
  >;
};

type LoginResponse = {
  access_token?: string;
  error_message?: string;
  message?: string;
};

type ValidateTokenResponse = {
  result?: boolean;
  token_scope?: "default" | "two_factor" | string | null;
};

type VerifyTotpResponse = {
  token?: string;
  error_message?: string;
  message?: string;
};

function usage(): never {
  console.error(`usage:
  node scripts/putio-auth-harness.ts auth-status [profile]
  node scripts/putio-auth-harness.ts auth-prepare [profile]
  node scripts/putio-auth-harness.ts auth-approve-device <device-code> [profile]

environment:
  PUTIO_CLI_PROFILE=devs-fe-auto
  PUTIO_CLI_CONFIG_PATH=.putio-cli/devs-fe-auto.json
  PUTIO_HARNESS_ACCOUNT_ITEM=putio-test-account
  PUTIO_HARNESS_ACCOUNT_VAULT=frontend-dev
  PUTIO_HARNESS_OAUTH_ITEM=putio-oauth-first-party
  PUTIO_HARNESS_OAUTH_VAULT=frontend-dev`);
  process.exit(1);
}

function profileFromArg(rawProfile?: string): string {
  return rawProfile?.trim() || process.env.PUTIO_CLI_PROFILE?.trim() || defaultProfile;
}

function apiBaseUrl(): string {
  return process.env.PUTIO_CLI_API_BASE_URL?.trim() || defaultApiBaseUrl;
}

function configPathForProfile(profile: string): string {
  const rawPath = process.env.PUTIO_CLI_CONFIG_PATH?.trim();

  if (rawPath) {
    return isAbsolute(rawPath) ? rawPath : join(process.cwd(), rawPath);
  }

  return join(process.cwd(), ".putio-cli", `${profile}.json`);
}

function commandEnv(profile: string): NodeJS.ProcessEnv {
  return {
    ...process.env,
    PUTIO_CLI_PROFILE: profile,
    PUTIO_CLI_CONFIG_PATH: configPathForProfile(profile),
  };
}

async function runJson(command: string, args: ReadonlyArray<string>, profile: string): Promise<unknown> {
  const { stdout } = await execFile(command, args, {
    env: commandEnv(profile),
    maxBuffer: 1024 * 1024,
  });

  return parseJsonText(stdout, `${command} ${args.join(" ")}`);
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

function expectRecord(value: unknown, context: string): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new Error(`Expected ${context} to be an object`);
  }

  return value;
}

function optionalString(record: Record<string, unknown>, key: string): string | undefined {
  const value = record[key];
  return typeof value === "string" ? value : undefined;
}

function optionalBoolean(record: Record<string, unknown>, key: string): boolean | undefined {
  const value = record[key];
  return typeof value === "boolean" ? value : undefined;
}

function optionalNullableString(record: Record<string, unknown>, key: string): string | null | undefined {
  const value = record[key];
  if (value === null) {
    return null;
  }

  return typeof value === "string" ? value : undefined;
}

function requiredString(record: Record<string, unknown>, key: string, context: string): string {
  const value = optionalString(record, key);
  if (value === undefined) {
    throw new Error(`Expected ${context}.${key} to be a string`);
  }

  return value;
}

function parsePutioDescribe(value: unknown): PutioDescribe {
  const record = expectRecord(value, "putio describe response");
  const authValue = record.auth;
  const auth = isRecord(authValue)
    ? { profileEnv: optionalString(authValue, "profileEnv") }
    : undefined;
  const commandsValue = record.commands;
  const commands = Array.isArray(commandsValue)
    ? commandsValue.flatMap((commandValue) => {
        if (!isRecord(commandValue)) {
          return [];
        }

        const command = optionalString(commandValue, "command");
        if (command === undefined) {
          return [];
        }

        const inputValue = commandValue.input;
        const flagsValue = isRecord(inputValue) ? inputValue.flags : undefined;
        const flags = Array.isArray(flagsValue)
          ? flagsValue.flatMap((flagValue) => {
              if (!isRecord(flagValue)) {
                return [];
              }

              const name = optionalString(flagValue, "name");
              return name === undefined ? [] : [{ name }];
            })
          : undefined;

        return [{
          command,
          input: flags === undefined ? undefined : { flags },
        }];
      })
    : undefined;

  return { auth, commands };
}

function parseAuthStatus(value: unknown): AuthStatus {
  const record = expectRecord(value, "putio auth status response");
  const source = optionalNullableString(record, "source");

  return {
    authenticated: optionalBoolean(record, "authenticated") ?? false,
    source: source === undefined ? null : source,
    apiBaseUrl: requiredString(record, "apiBaseUrl", "auth status"),
    configPath: requiredString(record, "configPath", "auth status"),
    profile: optionalString(record, "profile"),
  };
}

function parseLoginResponse(value: unknown): LoginResponse {
  const record = isRecord(value) ? value : {};
  return {
    access_token: optionalString(record, "access_token"),
    error_message: optionalString(record, "error_message"),
    message: optionalString(record, "message"),
  };
}

function parseValidateTokenResponse(value: unknown): ValidateTokenResponse {
  const record = isRecord(value) ? value : {};
  return {
    result: optionalBoolean(record, "result"),
    token_scope: optionalNullableString(record, "token_scope"),
  };
}

function parseVerifyTotpResponse(value: unknown): VerifyTotpResponse {
  const record = isRecord(value) ? value : {};
  return {
    token: optionalString(record, "token"),
    error_message: optionalString(record, "error_message"),
    message: optionalString(record, "message"),
  };
}

function parsePutioConfig(value: unknown): PutioConfig {
  const record = expectRecord(value, "put.io CLI config");
  const rawProfiles = record.profiles;
  const profiles: Record<string, { api_base_url: string; auth_token: string }> = {};

  if (isRecord(rawProfiles)) {
    for (const [profile, rawProfile] of Object.entries(rawProfiles)) {
      if (!isRecord(rawProfile)) {
        continue;
      }

      const authToken = optionalString(rawProfile, "auth_token");
      if (authToken === undefined) {
        continue;
      }

      profiles[profile] = {
        api_base_url: optionalString(rawProfile, "api_base_url") ?? apiBaseUrl(),
        auth_token: authToken,
      };
    }
  }

  return {
    api_base_url: optionalString(record, "api_base_url") ?? apiBaseUrl(),
    auth_token: optionalString(record, "auth_token"),
    default_profile: optionalString(record, "default_profile"),
    profiles: Object.keys(profiles).length === 0 ? undefined : profiles,
  };
}

function parseMessageResponse(value: unknown): { error_message?: string; message?: string } {
  const record = isRecord(value) ? value : {};
  return {
    error_message: optionalString(record, "error_message"),
    message: optionalString(record, "message"),
  };
}

function hasProfileSupport(describe: PutioDescribe): boolean {
  if (describe.auth?.profileEnv) {
    return true;
  }

  return (
    describe.commands?.some(
      (command) =>
        command.command === "auth status" &&
        command.input?.flags?.some((flag) => flag.name === "profile"),
    ) ?? false
  );
}

async function describePutio(profile: string): Promise<PutioDescribe> {
  return parsePutioDescribe(await runJson("putio", ["describe"], profile));
}

async function readAuthStatus(profile: string): Promise<AuthStatus> {
  const describe = await describePutio(profile);
  const args = hasProfileSupport(describe)
    ? ["auth", "status", "--profile", profile, "--output", "json"]
    : ["auth", "status", "--output", "json"];

  return parseAuthStatus(await runJson("putio", args, profile));
}

function opItemArgs(item: string, vault: string | undefined): string[] {
  const args = ["item", "get", item];

  if (vault !== undefined && vault !== "") {
    args.push("--vault", vault);
  }

  return args;
}

async function opField(item: string, field: string, vault?: string): Promise<string> {
  const { stdout } = await execFile("op", [...opItemArgs(item, vault), "--field", field, "--reveal"], {
    maxBuffer: 1024 * 1024,
  });
  const value = stdout.trim();

  if (value === "") {
    throw new Error(`1Password item ${item} field ${field} is empty`);
  }

  return value;
}

async function opOtp(item: string, vault?: string): Promise<string> {
  const { stdout } = await execFile("op", [...opItemArgs(item, vault), "--otp"], {
    maxBuffer: 1024 * 1024,
  });
  const value = stdout.trim();

  if (value === "") {
    throw new Error(`1Password item ${item} one-time password is empty`);
  }

  return value;
}

async function loginWithPassword(input: {
  clientId: string;
  clientSecret: string;
  password: string;
  username: string;
}): Promise<string> {
  const credentials = Buffer.from(`${input.username}:${input.password}`, "utf8").toString("base64");
  const url = new URL(`/v2/oauth2/authorizations/clients/${encodeURIComponent(input.clientId)}`, apiBaseUrl());
  url.searchParams.set("client_name", "putio-roku harness");
  url.searchParams.set("client_secret", input.clientSecret);

  const response = await fetch(url, {
    headers: {
      Authorization: `Basic ${credentials}`,
    },
    method: "PUT",
  });
  const data = parseLoginResponse(await response.json().catch(() => ({})));

  if (!response.ok || typeof data.access_token !== "string" || data.access_token === "") {
    throw new Error(
      data.error_message ?? data.message ?? `put.io login failed with HTTP ${response.status}`,
    );
  }

  return data.access_token;
}

async function validateToken(token: string): Promise<ValidateTokenResponse> {
  const url = new URL("/v2/oauth2/validate", apiBaseUrl());
  url.searchParams.set("oauth_token", token);

  const response = await fetch(url);

  if (!response.ok) {
    return { result: false };
  }

  return parseValidateTokenResponse(await response.json().catch(() => ({ result: false })));
}

async function verifyTotpToken(twoFactorToken: string, code: string): Promise<string> {
  const url = new URL("/v2/two_factor/verify/totp", apiBaseUrl());
  url.searchParams.set("oauth_token", twoFactorToken);

  const response = await fetch(url, {
    body: new URLSearchParams({ code }),
    method: "POST",
  });
  const data = parseVerifyTotpResponse(await response.json().catch(() => ({})));

  if (!response.ok || typeof data.token !== "string" || data.token === "") {
    throw new Error(
      data.error_message ?? data.message ?? `TOTP verification failed with HTTP ${response.status}`,
    );
  }

  return data.token;
}

async function resolveLoginToken(token: string, accountItem: string, accountVault: string | undefined): Promise<string> {
  const validation = await validateToken(token);

  if (validation.result && validation.token_scope !== "two_factor") {
    return token;
  }

  if (validation.result && validation.token_scope === "two_factor") {
    const otp = await opOtp(accountItem, accountVault);
    const verifiedToken = await verifyTotpToken(token, otp);
    const verifiedValidation = await validateToken(verifiedToken);

    if (verifiedValidation.result && verifiedValidation.token_scope !== "two_factor") {
      return verifiedToken;
    }
  }

  throw new Error("put.io login did not produce a usable default-scope token");
}

async function materializeToken(): Promise<string> {
  const accountItem = process.env.PUTIO_HARNESS_ACCOUNT_ITEM?.trim() || defaultAccountItem;
  const oauthItem = process.env.PUTIO_HARNESS_OAUTH_ITEM?.trim() || defaultOAuthItem;
  const accountVault = process.env.PUTIO_HARNESS_ACCOUNT_VAULT?.trim();
  const oauthVault = process.env.PUTIO_HARNESS_OAUTH_VAULT?.trim();
  const username = await opField(accountItem, "username", accountVault);
  const email = await opField(accountItem, "email", accountVault).catch(() => "");
  const password = await opField(accountItem, "password", accountVault);
  const otp = await opOtp(accountItem, accountVault).catch(() => "");
  const clientId = await opField(oauthItem, "CLIENT_ID", oauthVault);
  const clientSecret = await opField(oauthItem, "CLIENT_SECRET", oauthVault);
  const usernames = [...new Set([username, email].filter((value) => value !== ""))];
  const passwords = [...new Set([password, otp === "" ? "" : `${password}${otp}`].filter((value) => value !== ""))];
  let lastError: unknown;

  for (const candidateUsername of usernames) {
    for (const candidatePassword of passwords) {
      try {
        const token = await loginWithPassword({
          clientId,
          clientSecret,
          password: candidatePassword,
          username: candidateUsername,
        });

        return await resolveLoginToken(token, accountItem, accountVault);
      } catch (error) {
        lastError = error;
      }
    }
  }

  throw lastError instanceof Error ? lastError : new Error("put.io login failed");
}

async function writeConfig(profile: string, token: string): Promise<string> {
  const configPath = configPathForProfile(profile);
  const config: PutioConfig = {
    api_base_url: apiBaseUrl(),
    auth_token: token,
    default_profile: profile,
    profiles: {
      [profile]: {
        api_base_url: apiBaseUrl(),
        auth_token: token,
      },
    },
  };

  await mkdir(dirname(configPath), { recursive: true });
  await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`, { mode: 0o600 });
  await chmod(configPath, 0o600);

  return configPath;
}

async function readPreparedToken(profile: string): Promise<string> {
  const envToken = process.env.PUTIO_CLI_TOKEN?.trim();

  if (envToken) {
    return envToken;
  }

  const config = parsePutioConfig(parseJsonText(
    await readFile(configPathForProfile(profile), "utf8"),
    configPathForProfile(profile),
  ));
  const token = config.profiles?.[profile]?.auth_token ?? config.auth_token;

  if (!token) {
    throw new Error(`No put.io token is configured for ${profile}. Run auth-prepare first.`);
  }

  return token;
}

async function approveDeviceCode(profile: string, code: string): Promise<void> {
  const token = await readPreparedToken(profile);
  const body = new URLSearchParams({ code: code.trim().toUpperCase() });
  const response = await fetch(new URL("/v2/oauth2/oob/code", apiBaseUrl()), {
    body,
    headers: {
      Authorization: `token ${token}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    method: "POST",
  });
  const data = parseMessageResponse(await response.json().catch(() => ({})));

  if (!response.ok) {
    throw new Error(
      data.error_message ?? data.message ?? `device-code approval failed with HTTP ${response.status}`,
    );
  }
}

async function authStatus(profile: string): Promise<void> {
  const status = await readAuthStatus(profile);
  const token = await readPreparedToken(profile).catch(() => undefined);
  const validation = token === undefined ? { result: false } : await validateToken(token);

  console.log(
    JSON.stringify(
      {
        ...status,
        authenticated:
          status.authenticated && validation.result === true && validation.token_scope !== "two_factor",
        configPath: configPathForProfile(profile),
        profile,
        tokenScope: validation.token_scope ?? null,
      },
      null,
      2,
    ),
  );
}

async function authPrepare(profile: string): Promise<void> {
  const before = await readAuthStatus(profile);
  const accountItem = process.env.PUTIO_HARNESS_ACCOUNT_ITEM?.trim() || defaultAccountItem;
  const accountVault = process.env.PUTIO_HARNESS_ACCOUNT_VAULT?.trim();

  if (before.authenticated) {
    const existingToken = await readPreparedToken(profile).catch(() => undefined);
    const existingValidation =
      existingToken === undefined ? { result: false } : await validateToken(existingToken);

    if (existingValidation.result && existingValidation.token_scope !== "two_factor") {
      console.log(
        JSON.stringify(
          {
            status: "ok",
            authenticated: true,
            configPath: configPathForProfile(profile),
            message: "put.io CLI auth is already prepared",
            profile,
          },
          null,
          2,
        ),
      );
      return;
    }

    if (existingToken !== undefined && existingValidation.token_scope === "two_factor") {
      const token = await resolveLoginToken(existingToken, accountItem, accountVault);
      const configPath = await writeConfig(profile, token);

      console.log(
        JSON.stringify(
          {
            status: "ok",
            authenticated: true,
            configPath,
            message: "put.io CLI auth prepared",
            profile,
          },
          null,
          2,
        ),
      );
      return;
    }
  }

  const token = await materializeToken();
  const configPath = await writeConfig(profile, token);
  const after = await readAuthStatus(profile);

  if (!after.authenticated) {
    throw new Error(`put.io CLI auth setup wrote ${configPath}, but status is still unauthenticated`);
  }

  console.log(
    JSON.stringify(
      {
        status: "ok",
        authenticated: true,
        configPath,
        message: "put.io CLI auth prepared",
        profile,
      },
      null,
      2,
    ),
  );
}

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);

  if (command === "auth-status") {
    await authStatus(profileFromArg(args[0]));
  } else if (command === "auth-prepare") {
    await authPrepare(profileFromArg(args[0]));
  } else if (command === "auth-approve-device") {
    const [code, rawProfile] = args;

    if (!code) {
      usage();
    }

    const profile = profileFromArg(rawProfile);
    await approveDeviceCode(profile, code);
    console.log(
      JSON.stringify(
        {
          status: "ok",
          code: code.trim().toUpperCase(),
          message: "device code approved",
          profile,
        },
        null,
        2,
      ),
    );
  } else {
    usage();
  }
}

main().catch((error: unknown) => {
  console.error(`ERROR: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
