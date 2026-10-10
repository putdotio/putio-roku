' Builds the Sentry event for a terminal Roku playback failure. Mirrors the
' putio-web `playback_failure` telemetry contract (schema_version 1) so one Sentry
' search covers every put.io player: tags group and filter, extra carries detail.
function createPlaybackFailureEvent(input as object) as object
    video = input.video
    errorCode = sentryVideoErrorCode(video)
    errorInfo = sentryVideoErrorInfo(video)
    failureMode = classifyRokuPlaybackFailure(errorCode, errorInfo)
    streamInfo = input.streamInfo
    file = input.file
    sourceKind = sentryPlaybackSourceKind(streamInfo)
    videoStream = sentryFileVideoStream(file)
    audioStream = sentryFileAudioStream(file)

    event = sentryCreateEvent("Roku playback failed: " + failureMode, "error")
    event.fingerprint = ["roku-playback-error", "failure:" + failureMode, "roku-code:" + errorCode]

    sentryAddTags(event, {
        telemetry_event: "playback_failure",
        schema_version: "1",
        player: "roku",
        playback_outcome: "failed",
        playback_terminal: "true",
        playback_failure_mode: failureMode,
        playback_started: input.playbackStarted,
        playback_type: input.playbackType,
        roku_error_code: errorCode,
        roku_error_category: sentryErrorInfoField(errorInfo, "category"),
        roku_error_source: sentryErrorInfoField(errorInfo, "source"),
        source_kind: sourceKind,
        stream_format: sentryStreamFormat(streamInfo),
        file_id: sentryFileId(file),
        file_extension: sentryFileExtension(file),
        container_family: sentryContainerFamily(file),
        video_codec: sentryStreamField(videoStream, "codec_name"),
        video_profile: sentryStreamField(videoStream, "profile"),
        video_resolution: sentryVideoResolution(videoStream),
        video_pixel_format: sentryStreamField(videoStream, "pix_fmt"),
        audio_codec: sentryStreamField(audioStream, "codec_name"),
    })

    sentryAddExtra(event, {
        telemetry_event: "playback_failure",
        schema_version: 1,
        terminal: true,
        file_id: sentryFileId(file),
        file_size: sentryFileSize(file),
        playback_started: input.playbackStarted,
        playback_type: input.playbackType,
        current_time_seconds: input.position,
        duration_seconds: input.duration,
        time_to_error_ms: input.timeToErrorMs,
        video_state: sentryVideoState(video),
        roku_error_code: errorCode,
        roku_error_info: sentryAllowedFields(errorInfo, sentryErrorInfoKeys()),
        stream_format: sentryStreamFormat(streamInfo),
        source_kind: sourceKind,
        has_mp4_stream: sentryHasMp4Stream(file),
        has_direct_stream: sentryHasDirectStream(file),
        need_convert: sentryScalarValue(sentryFileField(file, "need_convert")),
        mp4_status: sentryMp4Status(file),
        video_metadata: sentryAllowedFields(sentryFileField(file, "video_metadata"), sentryVideoMetadataKeys()),
        media_info: sentryMediaInfoSummary(sentryFileField(file, "media_info")),
    })

    return event
end function

' Builds the event for a failed /files/list request behind the player. The API's
' error_message is free text that can quote the file name, so only codes are reported.
function createSourceRequestFailureEvent(fileId as dynamic, response as dynamic) as object
    errorType = "none"
    statusCode = invalid
    if type(response) = "roAssociativeArray"
        errorType = sentryTagValue(response.error_type)
        statusCode = sentryScalarValue(response.status_code)
    end if

    event = sentryCreateEvent("Roku video file request failed: " + errorType, "error")
    event.fingerprint = ["roku-video-fetch-error", "error-type:" + errorType]
    sentryAddTags(event, {
        telemetry_event: "playback_source_request_failure",
        source_request_error_type: errorType,
    })
    sentryAddExtra(event, {
        file_id: sentryScalarValue(fileId),
        error_type: errorType,
        status_code: statusCode,
    })

    return event
end function

' Roku Video.errorCode: -1 network, -2 connection timed out, -3 unknown, -4 empty
' playlist, -5 media/format error, -6 DRM. errorInfo.category refines it on OS 9+.
function classifyRokuPlaybackFailure(errorCode as string, errorInfo as object) as string
    category = LCase(sentryErrorInfoField(errorInfo, "category"))

    if category = "http" or category = "network"
        return "network"
    else if category = "drm"
        return "drm"
    else if category = "mediaerror"
        return "decode"
    end if

    if errorCode = "-1" or errorCode = "-2"
        return "network"
    else if errorCode = "-4"
        return "load"
    else if errorCode = "-5"
        return "unsupported_source"
    else if errorCode = "-6"
        return "drm"
    else if errorCode = "-3" or errorCode = "none"
        return "unknown"
    end if

    return "unknown"
end function

function sentryVideoErrorCode(video as object) as string
    if video <> invalid and video.errorCode <> invalid and video.errorCode.toStr() <> "" and video.errorCode.toStr() <> "0"
        return video.errorCode.toStr()
    end if

    return "none"
end function

function sentryVideoErrorInfo(video as object) as object
    if video <> invalid and video.hasField("errorInfo") and video.errorInfo <> invalid and type(video.errorInfo) = "roAssociativeArray"
        return video.errorInfo
    end if

    return invalid
end function

function sentryVideoState(video as object) as string
    if video <> invalid and video.state <> invalid
        return video.state.toStr()
    end if

    return "unknown"
end function

function sentryErrorInfoField(errorInfo as object, key as string) as string
    if errorInfo <> invalid and errorInfo[key] <> invalid
        return sentryTagValue(errorInfo[key])
    end if

    return "none"
end function

function sentryPlaybackSourceKind(streamInfo as object) as string
    if streamInfo = invalid or streamInfo.url = invalid
        return "unknown"
    end if

    url = LCase(streamInfo.url.toStr())
    if Instr(1, url, "/hls/") > 0 or Instr(1, url, ".m3u8") > 0
        return "hls"
    else if Instr(1, url, "/stream/") > 0
        return "direct"
    end if

    return "mp4"
end function

function sentryStreamFormat(streamInfo as object) as string
    if streamInfo <> invalid and streamInfo.format <> invalid
        return LCase(streamInfo.format.toStr())
    end if

    return "unknown"
end function

function sentryFileField(file as object, key as string) as dynamic
    if file <> invalid and file[key] <> invalid
        return file[key]
    end if

    return invalid
end function

function sentryFileId(file as object) as string
    id = sentryFileField(file, "id")
    if id = invalid
        return "unknown"
    end if

    return id.toStr()
end function

function sentryFileSize(file as object) as dynamic
    return sentryFileField(file, "size")
end function

function sentryFileExtension(file as object) as string
    extension = sentryFileField(file, "extension")
    if extension = invalid or extension.toStr() = ""
        return "unknown"
    end if

    return LCase(extension.toStr())
end function

function sentryContainerFamily(file as object) as string
    candidates = []
    contentType = sentryFileField(file, "content_type")
    if contentType <> invalid
        candidates.push(LCase(contentType.toStr()))
    end if
    mediaInfo = sentryFileField(file, "media_info")
    if mediaInfo <> invalid and mediaInfo.format <> invalid and mediaInfo.format.format_name <> invalid
        candidates.push(LCase(mediaInfo.format.format_name.toStr()))
    end if
    candidates.push(sentryFileExtension(file))

    for each candidate in candidates
        if Instr(1, candidate, "matroska") > 0 or candidate = "mkv"
            return "matroska"
        else if Instr(1, candidate, "webm") > 0
            return "webm"
        else if Instr(1, candidate, "mp4") > 0 or Instr(1, candidate, "m4v") > 0
            return "mp4"
        else if Instr(1, candidate, "quicktime") > 0 or candidate = "mov"
            return "quicktime"
        else if Instr(1, candidate, "mpegts") > 0 or Instr(1, candidate, "mp2t") > 0 or candidate = "ts"
            return "mpeg-ts"
        else if Instr(1, candidate, "avi") > 0
            return "avi"
        end if
    end for

    return "unknown"
end function

function sentryFileMediaStream(file as object, codecType as string) as object
    mediaInfo = sentryFileField(file, "media_info")
    if mediaInfo = invalid or mediaInfo.streams = invalid
        return invalid
    end if

    for each stream in mediaInfo.streams
        if stream <> invalid and stream.codec_type <> invalid and stream.codec_type.toStr() = codecType
            return stream
        end if
    end for

    return invalid
end function

function sentryFileVideoStream(file as object) as object
    return sentryFileMediaStream(file, "video")
end function

function sentryFileAudioStream(file as object) as object
    return sentryFileMediaStream(file, "audio")
end function

function sentryStreamField(stream as object, key as string) as string
    if stream = invalid or stream[key] = invalid
        return "unknown"
    end if

    return LCase(sentryTagValue(stream[key]))
end function

function sentryVideoResolution(stream as object) as string
    if stream = invalid
        return "unknown"
    end if

    width = sentryStreamField(stream, "width")
    height = sentryStreamField(stream, "height")
    if width = "unknown" or height = "unknown"
        return "unknown"
    end if

    return width + "x" + height
end function

function sentryHasMp4Stream(file as object) as boolean
    return sentryFileField(file, "mp4_stream_url") <> invalid
end function

function sentryHasDirectStream(file as object) as boolean
    return sentryFileField(file, "stream_url") <> invalid
end function

function sentryMp4Status(file as object) as dynamic
    mp4Status = sentryFileField(file, "mp4_status")
    if type(mp4Status) = "roAssociativeArray"
        return sentryScalarValue(mp4Status.status)
    end if

    return sentryScalarValue(mp4Status)
end function

' Roku errorInfo also carries message, dbgmsg and error_string, which can quote the
' stream URL with its token.
function sentryErrorInfoKeys() as object
    return ["category", "source", "error_code", "drm_error_code", "ignored"]
end function

function sentryVideoMetadataKeys() as object
    return ["width", "height", "codec", "duration", "aspect_ratio"]
end function

' media_info is ffprobe output: format and stream tags carry titles and the filename.
function sentryMediaInfoSummary(mediaInfo as dynamic) as dynamic
    if type(mediaInfo) <> "roAssociativeArray"
        return invalid
    end if

    summary = {
        format: sentryAllowedFields(mediaInfo.format, ["name", "format_name", "duration", "bit_rate"]),
        mime_type: sentryScalarValue(mediaInfo.mime_type),
        playback_issues: [],
        streams: [],
    }

    if type(mediaInfo.playback_issues) = "roArray"
        for each issue in mediaInfo.playback_issues
            value = sentryScalarValue(issue)
            if value <> invalid
                summary.playback_issues.push(value)
            end if
        end for
    end if

    if type(mediaInfo.streams) = "roArray"
        for each stream in mediaInfo.streams
            fields = sentryAllowedFields(stream, ["codec_type", "codec_name", "profile", "level", "width", "height", "pix_fmt", "channels", "rfc6381_codec"])
            if fields <> invalid
                summary.streams.push(fields)
            end if
        end for
    end if

    return summary
end function
