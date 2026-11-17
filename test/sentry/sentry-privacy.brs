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
        video: video,
        file: file,
        streamInfo: { url: streamUrl, format: "hls" },
        method: "file",
        source: "original",
        playbackStarted: true,
    })))

    result.playback_rescue_engine = parseJSON(formatJSON(createPlaybackRescueEvent({
        reason: "container_unsupported",
        trigger: "engine",
        method: "file",
        fromSource: "original",
        plan: { action: "play", source: "converted", url: streamUrl, streamFormat: "mp4", reason: "container_unsupported" },
        file: file,
        errorCode: "-5",
        errorInfo: video.errorInfo,
    })))

    result.playback_rescue_watchdog = parseJSON(formatJSON(createPlaybackRescueEvent({
        reason: "decoder_error",
        trigger: "watchdog",
        method: "file",
        fromSource: "original",
        plan: { action: "play", source: "converted", url: streamUrl, streamFormat: "mp4", reason: "decoder_error" },
        file: file,
        errorCode: invalid,
        errorInfo: invalid,
    })))

    result.playback_rescue_preflight = parseJSON(formatJSON(createPlaybackRescueEvent({
        reason: "audio_unsupported",
        trigger: "preflight",
        method: "file",
        fromSource: "original",
        plan: { action: "convert", source: "converted", url: invalid, streamFormat: invalid, reason: "audio_unsupported" },
        file: file,
    })))

    result.source_request_failure = parseJSON(formatJSON(createSourceRequestFailureEvent(9001, {
        error_type: "NotFound",
        error_message: "Secret.Movie.2026.mkv was not found at " + streamUrl,
        status_code: 404,
    })))

    return formatJSON(result)
end function

function sends() as boolean
    sentBefore = m.sentCount
    sentryCaptureEvent({})
    return m.sentCount > sentBefore
end function
