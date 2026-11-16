import process from "node:process";

export function putioProfileFromArg(rawProfile?: string): string {
  return rawProfile?.trim() || process.env.PUTIO_CLI_PROFILE?.trim() || "default";
}
