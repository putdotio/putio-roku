function getCleanSubtitleName(name) as string
    cleanName = name.toStr()
    dotIndex = 0
    position = Instr(1, cleanName, ".")
    while position > 0
        dotIndex = position
        position = Instr(position + 1, cleanName, ".")
    end while

    if dotIndex > 1 and isSubtitleFileExtension(LCase(Mid(cleanName, dotIndex + 1)))
        return Left(cleanName, dotIndex - 1)
    end if

    return cleanName
end function

function isSubtitleFileExtension(extension as string) as boolean
    for each known in ["srt", "vtt", "webvtt", "ass", "ssa", "sub", "smi", "sbv", "ttml", "dfxp", "txt"]
        if extension = known
            return true
        end if
    end for

    return false
end function

' Roku prefixes sidecar TrackNames it reports back (e.g. "<dev_9b1_1a>https://..."), so a sidecar matches on suffix.
function subtitleTrackNamesMatch(leftTrackName, rightTrackName) as boolean
    if leftTrackName = invalid or rightTrackName = invalid
        return false
    end if

    leftValue = leftTrackName.toStr()
    rightValue = rightTrackName.toStr()

    if leftValue = "" or rightValue = ""
        return false
    end if

    return leftValue = rightValue or Right(leftValue, Len(rightValue)) = rightValue or Right(rightValue, Len(leftValue)) = leftValue
end function
