function isPlaybackErrorFromServedCopy(source as dynamic) as boolean
    if source = invalid
        return false
    end if

    return source = "hls" or source = "converted"
end function

function buildPlaybackErrorDialogTitle(reason as string) as string
    if reason = "playback_stopped" or reason = "connection_lost"
        return "Playback stopped"
    else if reason = "link_expired"
        return "Playback link expired"
    end if

    return "Can't play this file"
end function

' Roku error codes and errorMsg go to Sentry only; the dialog shows the reason.
function buildPlaybackErrorDialogMessage(reason as string, source as dynamic) as string
    return getPlaybackErrorReasonMessage(reason, source)
end function

function buildUnplayableDialogMessage(reason as string, method as dynamic) as string
    message = getPlaybackErrorReasonMessage(reason, invalid)
    if normalizePlaybackMethod(method) = "file" and reason <> "not_ready" and reason <> "conversion_failed"
        message = message + chr(10) + "This file has no converted version."
    end if

    return message
end function

function getPlaybackErrorReasonMessage(reason as string, source as dynamic) as string
    if reason = "not_ready"
        return "This video isn't ready to play yet."
    else if reason = "playback_issue"
        return "The original file has a playback issue."
    else if reason = "container_unsupported"
        if isPlaybackErrorFromServedCopy(source)
            return "This file format can't be streamed."
        end if

        return "This Roku can't open this file format."
    else if reason = "video_unsupported"
        return "This Roku can't decode the video."
    else if reason = "audio_unsupported"
        return "This Roku can't decode the audio."
    else if reason = "decoder_error"
        if isPlaybackErrorFromServedCopy(source)
            return "This video failed to play."
        end if

        return "The original file failed to play."
    else if reason = "link_expired"
        return "Try again to get a fresh link."
    else if reason = "connection_lost"
        return "Connection lost. Check your internet and try again."
    else if reason = "conversion_failed"
        return "The conversion failed."
    end if

    return "Something went wrong while playing."
end function

function getPlaybackErrorDialogActions(reason as string, method as dynamic) as object
    if reason = "playback_stopped" or reason = "connection_lost" or reason = "link_expired" or reason = "conversion_failed"
        return ["retry", "back"]
    end if

    if normalizePlaybackMethod(method) = "file"
        return ["play_standard", "back"]
    end if

    return ["back"]
end function

function getPlaybackErrorDialogButtons(actions as object) as object
    buttons = []
    for each action in actions
        if action = "retry"
            buttons.push("Retry")
        else if action = "play_standard"
            buttons.push("Play with " + getPlaybackMethodLabel("hls"))
        else
            buttons.push("Back")
        end if
    end for

    return buttons
end function
