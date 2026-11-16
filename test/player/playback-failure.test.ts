import { beforeAll, describe, expect, it } from "vitest";
import { runBrsCases } from "./brs-cases.ts";

type Verdict = {
  action: "rescue" | "reresolve" | "retry" | "fail";
  reason: string;
  httpStatus: number | null;
};

type Input = {
  errorCode?: number | string;
  errorInfo?: Record<string, unknown> | null;
  errorStr?: string;
  started: boolean;
  source: "hls" | "original" | "converted";
  rescued: boolean;
  reresolved: boolean;
};

const original: Input = { started: false, source: "original", rescued: false, reresolved: false };
const http = (dbgmsg: string, category = "http") => ({ category, errcode: 0, dbgmsg, source: "buffer:loader" });
const verdict = (action: Verdict["action"], reason: string, httpStatus: number | null = null): Verdict => ({
  action,
  reason,
  httpStatus,
});

const cases: Record<string, { input: Input; expected: Verdict }> = {
  bad_request_with_http_category_rescues: {
    input: { ...original, errorCode: -1, errorInfo: http("HTTP status 400 Bad Request") },
    expected: verdict("rescue", "container_unsupported", 400),
  },
  bad_request_in_mediaplayer_category_rescues: {
    input: { ...original, errorCode: -3, errorInfo: http("exception:HTTP error code 400", "mediaplayer") },
    expected: verdict("rescue", "container_unsupported", 400),
  },
  forbidden_reresolves: {
    input: { ...original, errorCode: -3, errorInfo: http("HTTP status 403", "mediaplayer") },
    expected: verdict("reresolve", "link_expired", 403),
  },
  unauthorized_reresolves: {
    input: { ...original, errorCode: -3, errorInfo: http("http code: 401") },
    expected: verdict("reresolve", "link_expired", 401),
  },
  not_found_reresolves: {
    input: { ...original, errorCode: -3, errorInfo: http("HTTP/1.1 404 Not Found", "mediaplayer") },
    expected: verdict("reresolve", "link_expired", 404),
  },
  gone_reresolves: {
    input: { ...original, source: "converted", errorCode: -3, errorInfo: http("HTTP status 410") },
    expected: verdict("reresolve", "link_expired", 410),
  },
  second_expired_link_fails: {
    input: { ...original, reresolved: true, errorCode: -3, errorInfo: http("HTTP status 403", "mediaplayer") },
    expected: verdict("fail", "link_expired", 403),
  },
  network_error_reresolves: {
    input: { ...original, errorCode: -1, errorInfo: http("connection refused", "mediaplayer") },
    expected: verdict("reresolve", "link_expired"),
  },
  connection_timeout_reresolves: {
    input: { ...original, source: "hls", errorCode: "-2" },
    expected: verdict("reresolve", "link_expired"),
  },
  http_category_reresolves: {
    input: { ...original, errorCode: -3, errorInfo: http("download failed") },
    expected: verdict("reresolve", "link_expired"),
  },
  server_error_with_http_category_reresolves: {
    input: { ...original, errorCode: -3, errorInfo: http("HTTP status 503") },
    expected: verdict("reresolve", "link_expired", 503),
  },
  server_error_in_mediaplayer_category_rescues: {
    input: { ...original, errorCode: -3, errorInfo: http("HTTP status 503", "mediaplayer") },
    expected: verdict("rescue", "decoder_error", 503),
  },
  status_from_error_str: {
    input: {
      ...original,
      errorCode: -3,
      errorInfo: http("exception:HTTP server returned error code", "mediaplayer"),
      errorStr: "category_name:mediaplayer,error_code:-3,ignored:0,source:buffer,error_string:HTTP status 400",
    },
    expected: verdict("rescue", "container_unsupported", 400),
  },
  expired_status_from_error_str_without_error_info: {
    input: { ...original, errorCode: -3, errorInfo: null, errorStr: "error_string:'HTTP/1.1 410 Gone'" },
    expected: verdict("reresolve", "link_expired", 410),
  },
  unnumbered_http_message_rescues: {
    input: { ...original, errorCode: -3, errorInfo: http("exception:HTTP server returned error code", "mediaplayer") },
    expected: verdict("rescue", "decoder_error"),
  },
  file_id_in_url_is_not_a_status: {
    input: {
      ...original,
      errorCode: -3,
      errorInfo: http("open https://s1.put.io/stream/404?oauth_token=x&id=403 failed", "mediaplayer"),
    },
    expected: verdict("rescue", "decoder_error"),
  },
  error_code_key_is_ignored: {
    input: { ...original, errorCode: -3, errorInfo: { category: "mediaplayer", error_code: 403 } },
    expected: verdict("rescue", "decoder_error"),
  },
  media_format_error_rescues: {
    input: { ...original, errorCode: -5, errorInfo: { category: "mediaerror", errcode: 3, dbgmsg: "unsupported" } },
    expected: verdict("rescue", "container_unsupported"),
  },
  decoder_error_rescues: {
    input: { ...original, errorCode: -3, errorInfo: { category: "mediaerror", errcode: 7, dbgmsg: "decode failed" } },
    expected: verdict("rescue", "decoder_error"),
  },
  no_error_info_before_first_frame_rescues: {
    input: { ...original, errorCode: 0, errorInfo: null },
    expected: verdict("rescue", "decoder_error"),
  },
  second_rescue_fails: {
    input: { ...original, rescued: true, errorCode: -5 },
    expected: verdict("fail", "container_unsupported"),
  },
  converted_never_rescues: {
    input: { ...original, source: "converted", errorCode: -3, errorInfo: { category: "mediaerror", errcode: 7 } },
    expected: verdict("fail", "decoder_error"),
  },
  hls_bad_request_fails_as_container_unsupported: {
    input: { ...original, source: "hls", errorCode: -3, errorInfo: http("HTTP status 400", "mediaplayer") },
    expected: verdict("fail", "container_unsupported", 400),
  },
  hls_no_error_info_fails: {
    input: { ...original, source: "hls" },
    expected: verdict("fail", "decoder_error"),
  },
  after_first_frame_retries: {
    input: { ...original, started: true, errorCode: -3, errorInfo: { category: "mediaerror", errcode: 7 } },
    expected: verdict("retry", "playback_stopped"),
  },
  expired_link_after_first_frame_reresolves: {
    input: { ...original, started: true, errorCode: -3, errorInfo: http("HTTP status 403") },
    expected: verdict("reresolve", "link_expired", 403),
  },
  second_expired_link_after_first_frame_fails: {
    input: { ...original, started: true, reresolved: true, errorCode: -3, errorInfo: http("HTTP status 403") },
    expected: verdict("fail", "link_expired", 403),
  },
  expired_link_after_rescue_reresolves: {
    input: { ...original, source: "converted", rescued: true, errorCode: -3, errorInfo: http("HTTP status 403") },
    expected: verdict("reresolve", "link_expired", 403),
  },
  decoder_error_after_reresolve_rescues: {
    input: { ...original, reresolved: true, errorCode: -3, errorInfo: { category: "mediaerror", errcode: 7 } },
    expected: verdict("rescue", "decoder_error"),
  },
  status_with_trailing_dot: {
    input: { ...original, errorCode: -3, errorInfo: http("HTTP error 403.", "mediaplayer") },
    expected: verdict("reresolve", "link_expired", 403),
  },
  status_after_equals: {
    input: { ...original, errorCode: -3, errorInfo: http("request failed status=404", "mediaplayer") },
    expected: verdict("reresolve", "link_expired", 404),
  },
  status_before_newline: {
    input: { ...original, errorCode: -3, errorInfo: http("HTTP 410\nretrying", "mediaplayer") },
    expected: verdict("reresolve", "link_expired", 410),
  },
  status_in_brackets: {
    input: { ...original, errorCode: -3, errorInfo: http("http error [401]", "mediaplayer") },
    expected: verdict("reresolve", "link_expired", 401),
  },
  status_before_semicolon: {
    input: { ...original, errorCode: -3, errorInfo: http("code:404; aborting", "mediaplayer") },
    expected: verdict("reresolve", "link_expired", 404),
  },
  port_is_not_a_status: {
    input: { ...original, errorCode: -3, errorInfo: http("connect http s1.put.io:443 failed", "mediaplayer") },
    expected: verdict("rescue", "decoder_error"),
  },
  decoder_word_is_not_a_code_label: {
    input: { ...original, errorCode: -3, errorInfo: http("decoder init failed, 400 frames dropped", "mediaplayer") },
    expected: verdict("rescue", "decoder_error"),
  },
};

describe("classifyPlaybackFailure", () => {
  let results: Record<string, Verdict>;

  beforeAll(async () => {
    const inputs = Object.fromEntries(Object.entries(cases).map(([name, { input }]) => [name, input]));
    results = await runBrsCases<Verdict>(
      ["components/shared/Playback/PlaybackFailure.brs"],
      "test/player/playback-failure.brs",
      inputs,
    );
  });

  it.each(Object.entries(cases))("%s", (name, { expected }) => {
    expect(results[name]).toEqual(expected);
  });
});
