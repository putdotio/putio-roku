/// <reference path="../.sst/platform/config.d.ts" />

import { AWS_WILDCARD_CERT_ARN, ROKU_DOMAIN, putioDns } from "./shared.js";

export function createRokuSite() {
  return new sst.aws.StaticSite("putio-roku", {
    path: "dist/public",
    domain: {
      name: ROKU_DOMAIN,
      cert: AWS_WILDCARD_CERT_ARN,
      dns: putioDns(),
    },
    assets: {
      purge: false,
      fileOptions: [
        {
          files: "v2.zip",
          cacheControl: "public,max-age=300",
          contentType: "application/zip",
        },
        {
          files: "releases/**/*.zip",
          cacheControl: "public,max-age=31536000,immutable",
          contentType: "application/zip",
        },
      ],
    },
    invalidation: {
      paths: ["/v2.zip", "/releases/v2/*"],
      wait: true,
    },
  });
}
