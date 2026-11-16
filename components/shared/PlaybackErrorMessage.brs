function isPlaybackErrorFromServedCopy(source as dynamic) as boolean
    if source = invalid
        return false
    end if

    return source = "hls" or source = "converted"
end function

function buildPlaybackErrorDialogTitle(reason as string) as string
    if reason = "playback_stopped"
        return "Playback stopped"
    else if reason = "link_expired"
        return "Playback link expired"
    end if

    return "Can't play this file"
end function

' Roku's own errorMsg is developer text and stays out of the dialog.
function buildPlaybackErrorDialogMessage(reason as string, source as dynamic, errorCode as string) as string
    return appendPlaybackErrorCode(getPlaybackErrorReasonMessage(reason, source), errorCode)
end function

function buildUnplayableDialogMessage(reason as string, method as dynamic, errorCode as string) as string
    message = getPlaybackErrorReasonMessage(reason, invalid)
    if normalizePlaybackMethod(method) = "file" and reason <> "not_ready"
        message = message + chr(10) + "This file has no converted version."
    end if

    return appendPlaybackErrorCode(message, errorCode)
end function

function appendPlaybackErrorCode(message as string, errorCode as string) as string
    if errorCode <> "" and errorCode <> "none"
        return message + chr(10) + chr(10) + "Error " + errorCode
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
    end if

    return "Something went wrong while playing."
end function

function getPlaybackErrorDialogActions(reason as string, method as dynamic) as object
    if reason = "playback_stopped" or reason = "link_expired"
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
