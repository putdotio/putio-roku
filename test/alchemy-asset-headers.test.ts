import { createServer, type IncomingMessage, type Server } from "node:http";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createHash } from "node:crypto";
import type { AddressInfo } from "node:net";
import {
  type AssetDeployment,
  AssetDeploymentProvider,
} from "@alchemy.run/aws/Website/AssetDeployment";
import * as Credentials from "@distilled.cloud/aws/Credentials";
import * as Endpoint from "@distilled.cloud/aws/Endpoint";
import * as Region from "@distilled.cloud/aws/Region";
import * as NodeServices from "@effect/platform-node/NodeServices";
import { Provider } from "alchemy/Provider";
import { noopSession } from "alchemy/Report";
import * as Effect from "effect/Effect";
import * as Layer from "effect/Layer";
import * as Redacted from "effect/Redacted";
import * as FetchHttpClient from "effect/http/FetchHttpClient";
import { afterAll, beforeAll, expect, test } from "vitest";

type StoredObject = { body: Buffer; contentType: string; cacheControl: string };

const bucket = "site";
const objects = new Map<string, StoredObject>();
const puts: string[] = [];
const heads: string[] = [];
const goneAfterList = new Set<string>();
let server: Server;
let endpoint: string;

const etag = (body: Buffer) => `"${createHash("md5").update(body).digest("hex")}"`;

const readBody = async (request: IncomingMessage) => {
  const chunks: Buffer[] = [];
  for await (const chunk of request) chunks.push(chunk as Buffer);
  return Buffer.concat(chunks);
};

beforeAll(async () => {
  server = createServer(async (request, response) => {
    const url = new URL(request.url ?? "/", "http://localhost");
    const key = decodeURIComponent(url.pathname.replace(`/${bucket}`, "").replace(/^\//, ""));
    if (request.method === "GET" && !key) {
      const contents = [...objects]
        .map(([k, o]) => `<Contents><Key>${k}</Key><ETag>${etag(o.body)}</ETag></Contents>`)
        .join("");
      response.setHeader("content-type", "application/xml");
      response.end(
        `<?xml version="1.0"?><ListBucketResult><Name>${bucket}</Name><IsTruncated>false</IsTruncated>${contents}</ListBucketResult>`,
      );
      return;
    }
    if (request.method === "HEAD") {
      heads.push(key);
      const stored = goneAfterList.has(key) ? undefined : objects.get(key);
      if (!stored) {
        response.statusCode = 404;
        response.end();
        return;
      }
      response.setHeader("etag", etag(stored.body));
      response.setHeader("content-type", stored.contentType);
      response.setHeader("cache-control", stored.cacheControl);
      response.setHeader("content-length", String(stored.body.length));
      response.end();
      return;
    }
    if (request.method === "PUT") {
      const body = await readBody(request);
      objects.set(key, {
        body,
        contentType: String(request.headers["content-type"]),
        cacheControl: String(request.headers["cache-control"]),
      });
      puts.push(key);
      response.setHeader("etag", etag(body));
      response.end();
      return;
    }
    response.statusCode = 400;
    response.end();
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  endpoint = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

afterAll(() => {
  server.close();
});

type Output = AssetDeployment["Attributes"];

const deploy = (sourcePath: string, file: string, cacheControl: string, previous?: Output) =>
  Effect.gen(function* () {
    const provider = yield* Provider<AssetDeployment>("AWS.Website.AssetDeployment");
    return yield* provider.reconcile({
      id: "Files",
      fqn: "Files",
      instanceId: "files",
      olds: undefined,
      output: previous,
      bindings: [],
      news: {
        bucket: { bucketName: bucket },
        sourcePath,
        fileOptions: [{ files: file, cacheControl }],
      },
      session: noopSession,
    });
  }).pipe(
    Effect.provide(
      AssetDeploymentProvider().pipe(
        Layer.provideMerge(
          Layer.mergeAll(
            NodeServices.layer,
            FetchHttpClient.layer,
            Endpoint.of(endpoint),
            Region.of("us-east-1"),
            Credentials.fromCredentials(
              { accessKeyId: Redacted.make("test"), secretAccessKey: Redacted.make("test") },
              "us-east-1",
            ),
          ),
        ),
      ),
    ),
    Effect.runPromise,
  );

const site = (file: string, body: string) => {
  const dir = mkdtempSync(join(tmpdir(), "asset-headers-"));
  writeFileSync(join(dir, file), body);
  puts.length = 0;
  heads.length = 0;
  return dir;
};

test("a header-only change re-uploads files whose content did not change", async () => {
  const dir = site("index.json", "{}");
  const first = await deploy(dir, "index.json", "max-age=31536000,public,immutable");
  puts.length = 0;

  await deploy(dir, "index.json", "max-age=0,public,must-revalidate", first);

  expect(puts).toEqual(["index.json"]);
  expect(objects.get("index.json")?.cacheControl).toBe("max-age=0,public,must-revalidate");
});

test("unchanged files and headers make no S3 calls per file", async () => {
  const dir = site("same.json", "[]");
  const first = await deploy(dir, "same.json", "max-age=60,public");
  puts.length = 0;
  heads.length = 0;

  await deploy(dir, "same.json", "max-age=60,public", first);

  expect(puts).toEqual([]);
  expect(heads).toEqual([]);
});

test("without a previous deploy, unchanged files are checked but not re-uploaded", async () => {
  const dir = site("checked.json", "1");
  await deploy(dir, "checked.json", "max-age=60,public");
  puts.length = 0;

  await deploy(dir, "checked.json", "max-age=60,public");

  expect(heads).toContain("checked.json");
  expect(puts).toEqual([]);
});

test("a file deleted between listing and checking is uploaded", async () => {
  const dir = site("gone.json", "2");
  await deploy(dir, "gone.json", "max-age=60,public");
  puts.length = 0;
  goneAfterList.add("gone.json");

  await deploy(dir, "gone.json", "max-age=0,public");

  goneAfterList.delete("gone.json");
  expect(puts).toEqual(["gone.json"]);
});
