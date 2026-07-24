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
        {
          files: "vref/**/*.html",
          cacheControl: "public,max-age=300",
        },
        {
          files: "vref/**/*.json",
          cacheControl: "public,max-age=300",
        },
        {
          files: "vref/**/*.jpg",
          cacheControl: "public,max-age=86400",
        },
      ],
    },
    invalidation: {
      paths: ["/v2.zip", "/releases/v2/*", "/vref/*"],
      wait: true,
    },
  });
}
