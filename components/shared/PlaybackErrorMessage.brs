' AppDialog shows at most 8 body lines and abbreviates the rest, so the source, code,
' and the action hint share as few lines as possible and the hint stays last but short.
function buildPlaybackErrorDialogMessage(errorMessage as string, sourceLabel as string, errorCode as string) as string
    message = errorMessage
    if message = ""
        message = "Roku could not play this video."
    end if

    details = ""
    if sourceLabel <> ""
        details = "Source: " + sourceLabel
    end if
    if errorCode <> ""
        if details <> ""
            details = details + "  |  "
        end if
        details = details + "Roku error " + errorCode
    end if
    if details <> ""
        message = message + chr(10) + details
    end if

    return message + chr(10) + chr(10) + "Try another playback type in Settings."
end function
