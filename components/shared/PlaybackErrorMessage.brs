' failureMode comes from classifyRokuPlaybackFailure, so the dialog and Sentry agree on
' what went wrong. Roku's own errorMsg is developer text and stays out of the dialog.
function buildPlaybackErrorDialogTitle(playbackStarted as boolean) as string
    if playbackStarted
        return "Playback stopped"
    end if

    return "Can't play this video"
end function

function buildPlaybackErrorDialogMessage(failureMode as string, playbackType as string, errorCode as string) as string
    switchHint = "Try " + otherPlaybackTypeLabel(playbackType) + " in Settings > Video playback type."

    if failureMode = "network"
        message = "Connection lost. Check your internet and try again."
    else if failureMode = "drm"
        message = "This video is copy-protected."
    else if failureMode = "decode" or failureMode = "unsupported_source"
        message = "Your Roku doesn't support this format. " + switchHint
    else
        message = switchHint
    end if

    if errorCode <> "" and errorCode <> "none"
        message = message + chr(10) + chr(10) + "Error " + errorCode
    end if

    return message
end function

function otherPlaybackTypeLabel(playbackType as string) as string
    if LCase(playbackType) = "mp4"
        return "HLS"
    end if

    return "MP4"
end function
