import { readdirSync } from "node:fs";
import { join, relative } from "node:path";
import * as AWS from "@alchemy.run/aws";
import * as Alchemy from "alchemy";
import { Stage } from "alchemy/Stage";
import * as Effect from "effect/Effect";

const domain = "roku-next.put.io";
const sitePath = "dist/public";
const hostedZoneId = required("AWS_ROUTE53_ZONE_ID");
const tags = { Project: "putio-roku", Repo: "putdotio/putio-roku", ManagedBy: "Alchemy" };

export default Alchemy.Stack(
  "putio-roku",
  {
    providers: AWS.providers(),
    state: AWS.state({ name: "putio-frontend" }),
  },
  Effect.gen(function* () {
    const stage = yield* Stage;
    if (stage !== "production") {
      return yield* Effect.die(`putio-roku only deploys the production stage, not ${stage}.`);
    }

    const site = yield* AWS.Website.StaticSite("Site", {
      path: sitePath,
      build: {
        command: "true",
        output: ".",
        env: { ROKU_DEPLOY_RUN: process.env.GITHUB_RUN_ID ?? "local" },
      },
      bucketName: "putio-roku-production-068203738331",
      errorPage: "index.html",
      assets: { purge: false, fileOptions: fileOptions() },
      invalidation: {
        paths: ["/", "/index.html", "/v2.zip", "/releases/v2/*"],
        wait: true,
      },
      domain: { name: domain, cert: required("AWS_WILDCARD_CERT_ARN"), hostedZoneId },
      tags,
    });

    const { distribution } = site;
    if (!distribution) return yield* Effect.die("roku.put.io needs its own distribution.");

    yield* AWS.Route53.Record("AliasRecordAAAA", {
      hostedZoneId,
      name: domain,
      type: "AAAA",
      aliasTarget: {
        hostedZoneId: distribution.hostedZoneId,
        dnsName: distribution.domainName,
      },
    });

    return { url: site.url };
  }),
);

function fileOptions() {
  const files = readdirSync(sitePath, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => relative(sitePath, join(entry.parentPath, entry.name)));
  const releases = files.filter((file) => file.startsWith("releases/") && file.endsWith(".zip"));
  return [
    { files: "index.html", cacheControl: "public,max-age=300" },
    { files: "v2.zip", cacheControl: "public,max-age=300", contentType: "application/zip" },
    ...(releases.length > 0
      ? [
          {
            files: releases,
            cacheControl: "public,max-age=31536000,immutable",
            contentType: "application/zip",
          },
        ]
      : []),
  ];
}

function required(name: string) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} must be set for the roku deploy.`);
  return value;
}
