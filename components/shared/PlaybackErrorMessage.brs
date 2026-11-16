' failureMode comes from classifyRokuPlaybackFailure, so the dialog and Sentry agree on
' what went wrong. Roku's own errorMsg is developer text and stays out of the dialog.
function buildPlaybackErrorDialogTitle(playbackStarted as boolean) as string
    if playbackStarted
        return "Playback stopped"
    end if

    return "Can't play this video"
end function

function buildPlaybackErrorDialogMessage(failureMode as string, playbackStarted as boolean, playbackType as string, sourceLabel as string, errorCode as string) as string
    otherType = otherPlaybackTypeLabel(playbackType)
    switchHint = "Switching Video playback type to " + otherType + " in Settings may help."

    if failureMode = "network"
        message = "Your Roku lost its connection while loading this video."
        hint = "Check your internet connection and try again."
    else if failureMode = "decode" or failureMode = "unsupported_source"
        message = "Your Roku can't play this video's format."
        hint = switchHint
    else if failureMode = "load"
        message = "This video's stream came back empty."
        hint = switchHint
    else if failureMode = "drm"
        message = "This video is copy-protected, so your Roku can't play it."
        hint = ""
    else if playbackStarted
        message = "Your Roku ran into a problem partway through this video."
        hint = "Try again, or switch Video playback type to " + otherType + " in Settings."
    else
        message = "Your Roku couldn't start this video."
        hint = switchHint
    end if

    if hint <> ""
        message = message + chr(10) + hint
    end if

    details = playbackErrorDetails(sourceLabel, errorCode)
    if details <> ""
        message = message + chr(10) + chr(10) + details
    end if

    return message
end function

function otherPlaybackTypeLabel(playbackType as string) as string
    if LCase(playbackType) = "mp4"
        return "HLS"
    end if

    return "MP4"
end function

function playbackErrorDetails(sourceLabel as string, errorCode as string) as string
    if errorCode = "" or errorCode = "none"
        return sourceLabel
    end if

    details = "Error " + errorCode
    if sourceLabel <> ""
        details = details + " (" + sourceLabel + ")"
    end if

    return details
end function
