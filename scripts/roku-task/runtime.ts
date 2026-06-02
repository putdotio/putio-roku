import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";
import type { RokuContext } from "@putdotio/rokit";

export type EnvMap = NodeJS.ProcessEnv;
export type Variant = "production" | "development" | "lab";

export interface VariantConfig {
  readonly packageName: string;
  readonly title: string;
  readonly variant: Variant;
}

export const repoRoot = process.cwd();
export const distDir = "dist";
export const zipDir = join(distDir, "apps");
export const tmpDir = join(distDir, "tmp");
export const artifactName = "putio-roku-v2.zip";

const defaultProfile = "devs-fe-auto";

export function loadEnvFiles(paths: readonly string[]): void {
  for (let index = paths.length - 1; index >= 0; index -= 1) {
    const path = paths[index];
    if (path === undefined) {
      continue;
    }
    if (!existsSync(path)) {
      continue;
    }

    process.loadEnvFile(path);
  }
}

export function variantConfig(value: string | undefined): VariantConfig {
  const rawVariant = value ?? "production";
  const variant = rawVariant === "dev" ? "development" : rawVariant;
  if (variant === "production") {
    return { packageName: "put.io", title: "put.io", variant };
  }
  if (variant === "development") {
    return { packageName: "put.io-dev", title: "put.io Dev", variant };
  }
  if (variant === "lab") {
    return { packageName: "put.io-lab", title: "put.io Lab", variant };
  }

  throw new Error(`Unsupported ROKU_VARIANT "${rawVariant}". Expected production, development, or lab.`);
}

export function selectedVariantConfig(): VariantConfig {
  return variantConfig(process.env.ROKU_VARIANT);
}

export function appZipFile(config: VariantConfig): string {
  return join(zipDir, `${config.packageName}.zip`);
}

export function requireEnv(name: string, example: string): string {
  const value = process.env[name]?.trim();
  if (value === undefined || value === "") {
    throw new Error(`${name} is not set. Example: ${example}`);
  }

  return value;
}

export function envOr(name: string, fallback: string): string {
  const value = process.env[name];
  return value !== undefined && value !== "" ? value : fallback;
}

export function optionalEnv(name: string): string | undefined {
  const value = process.env[name];
  return value !== undefined && value !== "" ? value : undefined;
}

export function rokuTarget(): string {
  const target = optionalEnv("ROKU_DEV_TARGET") ?? optionalEnv("ROKIT_TARGET");
  if (target === undefined) {
    throw new Error("ROKU_DEV_TARGET or ROKIT_TARGET is not set");
  }

  return target;
}

export function rokuPassword(): string | undefined {
  return optionalEnv("ROKU_DEV_PASSWORD") ?? optionalEnv("ROKIT_PASSWORD");
}

export function requireRokuPassword(): string {
  const password = rokuPassword();
  if (password === undefined) {
    throw new Error("ROKU_DEV_PASSWORD or ROKIT_PASSWORD is not set");
  }

  return password;
}

export function rokuContext(timeoutMs = 10_000): RokuContext {
  const password = rokuPassword();
  return {
    target: rokuTarget(),
    timeoutMs,
    username: "rokudev",
    ...(password === undefined ? {} : { password }),
  };
}

export function rokuContextWithPassword(timeoutMs = 30_000): RokuContext & { readonly password: string } {
  return {
    ...rokuContext(timeoutMs),
    password: requireRokuPassword(),
  };
}

export function appEcpId(): string {
  return envOr("ROKU_APP_ECP_ID", "dev");
}

export function debugArtifactDir(): string {
  return envOr("ROKU_DEBUG_ARTIFACT_DIR", join(repoRoot, ".local/roku-debug"));
}

export function putioProfile(): string {
  return envOr("PUTIO_CLI_PROFILE", defaultProfile);
}

export function putioConfigPath(): string {
  return envOr("PUTIO_CLI_CONFIG_PATH", join(repoRoot, ".putio-cli", `${putioProfile()}.json`));
}

export function liveEnv(): EnvMap {
  const target = optionalEnv("ROKU_DEV_TARGET") ?? optionalEnv("ROKIT_TARGET");
  const nextEnv: EnvMap = { ...process.env, ROKU_APP_ECP_ID: appEcpId() };
  if (target !== undefined) {
    nextEnv.ROKU_DEV_TARGET = target;
    nextEnv.ROKIT_TARGET = target;
  }

  return nextEnv;
}

export function liveSecretEnv(): EnvMap {
  const nextEnv = liveEnv();
  const password = rokuPassword();
  if (password !== undefined) {
    nextEnv.ROKU_DEV_PASSWORD = password;
    nextEnv.ROKIT_PASSWORD = password;
  }

  return nextEnv;
}

export function liveDebugEnv(): EnvMap {
  return { ...liveEnv(), ROKU_DEBUG_ARTIFACT_DIR: debugArtifactDir() };
}

export function sideloadSecretEnv(): EnvMap {
  return { ...liveSecretEnv(), ROKU_APP_ECP_ID: "dev" };
}

export function putioAuthEnv(baseEnv: EnvMap = process.env): EnvMap {
  return {
    ...baseEnv,
    PUTIO_CLI_CONFIG_PATH: putioConfigPath(),
    PUTIO_CLI_PROFILE: putioProfile(),
  };
}

export function run(command: string, args: readonly string[], env: EnvMap = process.env): void {
  const result = spawnSync(command, [...args], {
    cwd: repoRoot,
    env,
    stdio: "inherit",
  });

  if (result.error !== undefined) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed with status ${result.status ?? "unknown"}`);
  }
}

export function runPnpm(args: readonly string[], env: EnvMap = process.env): void {
  run("pnpm", args, env);
}

export function runRokuLive(args: readonly string[], env: EnvMap = liveEnv()): void {
  run("node", ["scripts/roku-live-test.ts", ...args], env);
}

export function assertFile(path: string): void {
  if (!existsSync(path)) {
    throw new Error(`missing expected file: ${path}`);
  }
}

export async function withEnv<T>(values: Record<string, string>, task: () => T | Promise<T>): Promise<T> {
  const previous: Record<string, string | undefined> = {};
  for (const [key, value] of Object.entries(values)) {
    previous[key] = process.env[key];
    process.env[key] = value;
  }
  try {
    return await task();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  }
}

export function sleep(delayMs: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, delayMs));
}

export function timestamp(): string {
  return new Date().toISOString().replace(/[-:]/g, "").replace(/\..*$/, "").replace("T", "-");
}

export function splitWords(value: string): readonly string[] {
  return value.trim() === "" ? [] : value.trim().split(/\s+/);
}
