/// <reference path="../.sst/platform/config.d.ts" />

import { AWS_WILDCARD_CERT_ARN, ROKU_DOMAIN, putioDns } from "./shared.js";

export function createRokuSite() {
  return new sst.aws.StaticSite("putio-roku", {
    path: "dist/public",
    // Serve the redirect landing for the bare domain and for any unknown path,
    // so visitors reach the Roku help article instead of a raw S3 error.
    indexPage: "index.html",
    errorPage: "index.html",
    domain: {
      name: ROKU_DOMAIN,
      cert: AWS_WILDCARD_CERT_ARN,
      dns: putioDns(),
    },
    assets: {
      purge: false,
      fileOptions: [
        {
          files: "index.html",
          cacheControl: "public,max-age=300",
        },
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
      paths: ["/", "/index.html", "/v2.zip", "/releases/v2/*"],
      wait: true,
    },
  });
}
