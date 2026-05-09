/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    const stage = input?.stage ?? "dev";
    const awsProfile =
      process.env.AWS_ACCESS_KEY_ID || process.env.AWS_WEB_IDENTITY_TOKEN_FILE
        ? undefined
        : process.env.AWS_PROFILE;

    if (stage !== "production") {
      throw new Error("putio-roku only supports the production SST stage.");
    }

    return {
      name: "putio-roku",
      removal: "retain",
      protect: true,
      home: "aws",
      providers: {
        aws: {
          region: process.env.AWS_REGION ?? "eu-west-1",
          ...(awsProfile ? { profile: awsProfile } : {}),
          defaultTags: {
            tags: {
              Project: "putio-roku",
              ManagedBy: "SST",
              Repo: "putdotio/putio-roku",
              Stage: "production",
            },
          },
        },
      },
    };
  },
  async run() {
    const { createRokuSite } = await import("./infra/site.js");

    createRokuSite();
  },
});
