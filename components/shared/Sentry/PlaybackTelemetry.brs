' The put.io "Playback failure reports" event, schema 2: one event per terminal failure
' (error) or rescue (warning), anonymous, with only the contract's tags. Roku has no
' beforeSend, so this builder is the allowlist that sentry-privacy.test.ts pins.
function createPlaybackFailureEvent(input as object) as object
    outcome = "failed"
    level = "error"
    if sentryTagValue(input.outcome) = "rescued"
        outcome = "rescued"
        level = "warning"
    end if

    errorCode = sentryTagValue(input.errorCode)
    errorInfo = input.errorInfo
    if type(errorInfo) <> "roAssociativeArray"
        errorInfo = invalid
    end if

    failureMode = input.failureMode
    if failureMode = invalid
        failureMode = classifyRokuPlaybackFailure(errorCode, errorInfo, input.httpStatus)
    end if
    rescueReason = "none"
    rescueTo = "none"
    summary = failureMode
    if outcome = "rescued"
        rescueReason = sentryTagValue(input.rescueReason)
        rescueTo = sentryTagValue(input.rescueTo)
        summary = rescueReason
    end if

    sourceKind = "unknown"
    if input.sourceKind <> invalid
        sourceKind = sentryTagValue(input.sourceKind)
    end if
    deviceCheck = "skipped"
    if sourceKind = "original" and input.deviceCheck <> invalid
        deviceCheck = sentryTagValue(input.deviceCheck)
    end if

    file = input.file
    mediaInfo = sentryFileField(file, "media_info")
    videoStream = invalid
    audioStream = invalid
    if mediaInfo <> invalid and mediaInfo.streams <> invalid
        videoStream = getDirectPlayVideoStream(mediaInfo.streams)
        audioStream = getDirectPlayAudioStream(mediaInfo.streams)
    end if

    event = sentryCreateAnonymousEvent("playback " + outcome + ": " + summary, level)
    event.fingerprint = ["roku", outcome, summary, errorCode]

    sentryAddTags(event, {
        telemetry_event: "playback_failure",
        schema_version: "2",
        platform: "roku",
        player: "roku",
        playback_outcome: outcome,
        playback_terminal: outcome = "failed",
        playback_started: input.started,
        failure_mode: failureMode,
        streaming_method: input.method,
        source_kind: sourceKind,
        device_check: deviceCheck,
        rescue_reason: rescueReason,
        rescue_to: rescueTo,
        engine_error_domain: LCase(sentryErrorInfoField(errorInfo, "category")),
        engine_error_category: "none",
        engine_error_code: errorCode,
        source_request_status: input.httpStatus,
        file_id: sentryFileId(file),
        container_family: sentryContainerFamily(mediaInfo),
        video_codec: sentryStreamField(videoStream, "codec_name"),
        video_profile: sentryStreamField(videoStream, "profile"),
        video_level: sentryStreamField(videoStream, "level"),
        video_bit_depth: sentryStreamField(videoStream, "bit_depth"),
        video_resolution: sentryVideoResolution(videoStream),
        video_hdr: sentryStreamField(videoStream, "hdr"),
        audio_codec: sentryStreamField(audioStream, "codec_name"),
        audio_channels: sentryStreamField(audioStream, "channels"),
    })

    return event
end function

' Builds the event for a failed /files/list request behind the player. The API's
' error_message is free text that can quote the file name, so only codes are reported.
function createConversionFailureEvent(status as dynamic, method as dynamic, file as object) as object
    conversionStatus = sentryTagValue(status)
    event = sentryCreateEvent("Roku conversion failed: " + conversionStatus, "error")
    event.fingerprint = ["roku-conversion-failure", conversionStatus]
    sentryAddTags(event, {
        telemetry_event: "playback_conversion_failure",
        schema_version: "1",
        player: "roku",
        conversion_status: conversionStatus,
        streaming_method: method,
        file_id: sentryFileId(file),
    })

    return event
end function

function createSourceRequestFailureEvent(fileId as dynamic, response as dynamic) as object
    errorType = "none"
    statusCode = invalid
    if type(response) = "roAssociativeArray"
        errorType = sentryTagValue(response.error_type)
        statusCode = response.status_code
    end if

    event = sentryCreateEvent("Roku video file request failed: " + errorType, "error")
    event.fingerprint = ["roku-video-fetch-error", "error-type:" + errorType]
    sentryAddTags(event, {
        telemetry_event: "playback_source_request_failure",
        file_id: fileId,
        source_request_error_type: errorType,
        source_request_status_code: statusCode,
    })

    return event
end function

' A definitive stream status outranks the engine code. Roku Video.errorCode: -1 network,
' -2 connection timed out, -3 unknown, -4 empty playlist, -5 media/format error, -6 DRM.
' errorInfo.category refines it on OS 9+.
function classifyRokuPlaybackFailure(errorCode as string, errorInfo as object, httpStatus as dynamic) as string
    if httpStatus <> invalid
        if httpStatus = 404 or httpStatus = 410
            return "source_gone"
        else if httpStatus = 402
            return "entitlement"
        else if httpStatus = 429
            return "throttled"
        else if httpStatus = 408 or (httpStatus >= 500 and httpStatus <= 599)
            return "server_transient"
        end if
    end if

    category = LCase(sentryErrorInfoField(errorInfo, "category"))
    if category = "http"
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

function sentryErrorInfoField(errorInfo as object, key as string) as string
    if errorInfo <> invalid and errorInfo[key] <> invalid
        return sentryTagValue(errorInfo[key])
    end if

    return "none"
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

' The backend reports WebM as format.name "matroska"; only mime_type tells them apart.
function sentryContainerFamily(mediaInfo as object) as string
    if mediaInfo = invalid or mediaInfo.format = invalid
        return "unknown"
    end if

    mimeType = lowerDirectPlayField(mediaInfo, "mime_type")
    if mimeType = "video/webm" or mimeType = "audio/webm"
        return "webm"
    end if

    for each formatName in lowerDirectPlayField(mediaInfo.format, "name").split(",")
        formatName = formatName.trim()
        if formatName = "matroska"
            return "matroska"
        else if formatName = "mp4" or formatName = "mov" or formatName = "m4v"
            return "mp4"
        else if formatName = "avi"
            return "avi"
        else if formatName = "mpegts"
            return "mpeg-ts"
        else if formatName = "webm"
            return "webm"
        else if formatName = "ogg"
            return "ogg"
        end if
    end for

    return "other"
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
