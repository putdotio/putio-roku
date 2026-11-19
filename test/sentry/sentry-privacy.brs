' Driver for sentry-privacy.test.ts, run by the @rokucommunity/brs interpreter. Every
' value an event must never carry contains "secret". Returns the observed sends and the
' built events as JSON.
function main() as string
    m.global = _brs_.global
    m.global.addFields({ user: {} })
    _brs_.mockComponent("SentryTask", {})
    ' brs has no scene to hang tasks on, so dispatched tasks are counted instead.
    m.sentCount = 0
    _brs_.mockFunction("sentryRetainTask", sub(task)
        m.sentCount = m.sentCount + 1
    end sub)

    result = { sends: {} }
    result.sends.no_dsn = sends()

    _brs_.mockFunction("buildConfigSentryDsn", function() as string
        return "https://synthetic-key@sentry.example.invalid/1"
    end function)

    result.sends.no_account = sends()
    m.global.user = { user_id: 4242, settings: { history_enabled: true } }
    result.sends.key_missing = sends()
    m.global.user = { user_id: 4242, settings: { diagnostics_enabled: true } }
    result.sends.enabled = sends()
    m.global.user = { user_id: 4242, settings: { diagnostics_enabled: false } }
    result.sends.disabled = sends()

    m.global.user = {
        user_id: 4242,
        username: "secret-user",
        mail: "secret@example.invalid",
        avatar_url: "https://secret.example.invalid/avatar.png",
        download_token: "secret-token",
        private_download_host_ip: "secret-host",
        settings: { diagnostics_enabled: true, pushover_token: "secret-pushover", callback_url: "https://secret.example.invalid/callback" },
    }

    streamUrl = "https://secret.example.invalid/v2/files/9001/hls/media.m3u8?oauth_token=secret-token"
    video = createObject("roSGNode", "Node")
    video.addFields({
        errorCode: -1,
        errorMsg: "HTTP 403 for " + streamUrl,
        errorStr: "category:http:error:-1:message:" + streamUrl,
        errorInfo: {
            category: "http",
            source: "manifest",
            errcode: 403,
            message: "Forbidden " + streamUrl,
            dbgmsg: "HTTP 400 for GET " + streamUrl,
            error_string: "Secret.Movie.2026.mkv",
        },
        state: "error",
    })

    file = {
        id: 9001,
        name: "Secret.Movie.2026.mkv",
        extension: "secret movie s01e01",
        content_type: "video/x-matroska",
        stream_url: streamUrl,
        mp4_stream_url: streamUrl,
        mp4_status: { status: "COMPLETED", url: streamUrl },
        media_info: {
            format: { name: "matroska", filename: "/secret/Secret.Movie.2026.mkv", duration: 5400, bit_rate: 8000000 },
            streams: [
                { codec_type: "video", codec_name: "mjpeg", width: 600, height: 900 },
                { codec_type: "video", codec_name: "h264", profile: "High", level: 41, width: 1920, height: 1080, tags: { title: "Secret video title" } },
                { codec_type: "audio", codec_name: "dts", channels: 6, tags: { title: "Secret commentary", language: "eng" } },
            ],
        },
    }

    ' On a device every read of m.global.user is a fresh copy; brs shares one, which
    ' formatJSON rejects when two events hold it, so each event is serialized alone.
    result.playback_failure = parseJSON(formatJSON(createPlaybackFailureEvent({
        outcome: "failed",
        method: "hls",
        sourceKind: "hls",
        deviceCheck: "skipped",
        started: true,
        errorCode: sentryVideoErrorCode(video),
        errorInfo: sentryVideoErrorInfo(video),
        httpStatus: 404,
        file: file,
    })))

    result.playback_rescue_engine = parseJSON(formatJSON(createPlaybackFailureEvent({
        outcome: "rescued",
        rescueReason: "container_unsupported",
        rescueTo: "converted",
        method: "file",
        sourceKind: "original",
        deviceCheck: "pass",
        started: false,
        errorCode: "-5",
        errorInfo: { category: "mediaerror", source: "buffer:loop", errcode: -5, dbgmsg: "demux failed for " + streamUrl },
        file: file,
    })))

    result.playback_rescue_watchdog = parseJSON(formatJSON(createPlaybackFailureEvent({
        outcome: "rescued",
        rescueReason: "decoder_error",
        rescueTo: "converted",
        method: "file",
        sourceKind: "original",
        deviceCheck: "pass",
        started: false,
        errorCode: "none",
        file: file,
    })))

    result.playback_rescue_preflight = parseJSON(formatJSON(createPlaybackFailureEvent({
        outcome: "rescued",
        failureMode: "none",
        rescueReason: "audio_unsupported",
        rescueTo: "converted",
        method: "file",
        sourceKind: "original",
        deviceCheck: "fail",
        started: false,
        file: file,
    })))

    hevcFile = {
        id: 9002,
        name: "Secret.Show.S01E01.mkv",
        media_info: {
            mime_type: "video/x-matroska",
            format: { name: "matroska,webm", filename: "/secret/Secret.Show.S01E01.mkv" },
            streams: [
                { codec_type: "video", codec_name: "hevc", profile: "Main 10", level: 153, bit_depth: 10, width: 3840, height: 2160, hdr: true },
                { codec_type: "audio", codec_name: "aac", channels: 2, "default": false },
                { codec_type: "audio", codec_name: "eac3", channels: 6, "default": true, tags: { title: "Secret mix" } },
            ],
        },
    }
    result.playback_failure_hevc_original = parseJSON(formatJSON(createPlaybackFailureEvent({
        outcome: "failed",
        method: "file",
        sourceKind: "original",
        deviceCheck: "pass",
        started: false,
        errorCode: "-5",
        errorInfo: { category: "mediaerror", errcode: -5, message: "Secret.Show.S01E01.mkv failed" },
        file: hevcFile,
    })))

    result.source_request_failure = parseJSON(formatJSON(createSourceRequestFailureEvent(9001, {
        error_type: "NotFound",
        error_message: "Secret.Movie.2026.mkv was not found at " + streamUrl,
        status_code: 404,
    })))

    result.conversion_failure = parseJSON(formatJSON(createConversionFailureEvent("NOT_AVAILABLE", "hls", file)))

    return formatJSON(result)
end function

function sends() as boolean
    sentBefore = m.sentCount
    sentryCaptureEvent({})
    return m.sentCount > sentBefore
end function
