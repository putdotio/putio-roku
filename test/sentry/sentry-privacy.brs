' Driver for sentry-privacy.test.ts, run by the @rokucommunity/brs interpreter. Every
' value below is synthetic. Returns the observed gate states and built events as JSON.
function main() as string
    m.global = _brs_.global
    m.global.addFields({ user: {} })

    result = { gate: {} }
    result.gate.no_dsn = sentryIsEnabled()

    _brs_.mockFunction("buildConfigSentryDsn", function() as string
        return "https://synthetic-key@sentry.example.invalid/1"
    end function)

    result.gate.no_account = sentryIsEnabled()
    m.global.user = { user_id: 4242, settings: { history_enabled: true } }
    result.gate.key_missing = sentryIsEnabled()
    m.global.user = { user_id: 4242, settings: { diagnostics_enabled: true } }
    result.gate.enabled = sentryIsEnabled()
    m.global.user = { user_id: 4242, settings: { diagnostics_enabled: false } }
    result.gate.disabled = sentryIsEnabled()

    m.global.user = { user_id: 4242, settings: { diagnostics_enabled: true } }

    streamUrl = "https://api.example.invalid/v2/files/9001/hls/media.m3u8?oauth_token=synthetic-token-7f3a"
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
            error_string: "Synthetic.Secret.Movie.2026.mkv",
        },
        state: "error",
    })

    file = {
        id: 9001,
        name: "Synthetic.Secret.Movie.2026.mkv",
        size: 123456789,
        extension: "mkv",
        content_type: "video/x-matroska",
        stream_url: streamUrl,
        mp4_stream_url: streamUrl,
        need_convert: false,
        mp4_status: { status: "COMPLETED", url: streamUrl },
        video_metadata: { width: 1920, height: 1080, codec: "h264", duration: 5400, title: "Synthetic Secret Title" },
        media_info: {
            format: {
                format_name: "matroska,webm",
                duration: 5400,
                filename: "Synthetic.Secret.Movie.2026.mkv",
                tags: { title: "Synthetic Secret Title" },
            },
            streams: [
                { codec_type: "video", codec_name: "h264", profile: "High", width: 1920, height: 1080, pix_fmt: "yuv420p", tags: { title: "Synthetic Secret Title" } },
                { codec_type: "audio", codec_name: "aac", channels: 2, tags: { title: "Synthetic Secret Title", language: "eng" } },
            ],
        },
    }

    result.playback_failure = createPlaybackFailureEvent({
        video: video,
        file: file,
        streamInfo: { url: streamUrl, format: "hls" },
        playbackType: "hls",
        playbackStarted: true,
        position: 12,
        duration: 5400,
        timeToErrorMs: 1500,
    })

    result.source_request_failure = createSourceRequestFailureEvent(9001, {
        error_type: "NotFound",
        error_message: "Synthetic.Secret.Movie.2026.mkv was not found at " + streamUrl,
        status_code: 404,
    })

    return formatJSON(result)
end function
