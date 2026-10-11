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
            error_code: 403,
            message: "Forbidden " + streamUrl,
            dbgmsg: "GET " + streamUrl,
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
            format: { name: "matroska", duration: 5400, bit_rate: 8000000 },
            streams: [
                { codec_type: "video", codec_name: "h264", profile: "High", width: 1920, height: 1080 },
                { codec_type: "audio", codec_name: "aac", channels: 2 },
            ],
        },
    }

    ' On a device every read of m.global.user is a fresh copy; brs shares one, which
    ' formatJSON rejects when two events hold it, so each event is serialized alone.
    result.playback_failure = parseJSON(formatJSON(createPlaybackFailureEvent({
        video: video,
        file: file,
        streamInfo: { url: streamUrl, format: "hls" },
        playbackType: "hls",
        playbackStarted: true,
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
