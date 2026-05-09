/// <reference path="../.sst/platform/config.d.ts" />

export const ROKU_DOMAIN = process.env.ROKU_DOMAIN ?? "roku.put.io";

export const AWS_ROUTE53_ZONE_ID = requiredEnv("AWS_ROUTE53_ZONE_ID");

export const AWS_WILDCARD_CERT_ARN = requiredEnv("AWS_WILDCARD_CERT_ARN");

export function putioDns() {
  return sst.aws.dns({ zone: AWS_ROUTE53_ZONE_ID });
}

function requiredEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set for putio-roku infrastructure deploys.`);
  }
  return value;
}
