' put.io names each HLS subtitle rendition this way (putdotio/putio pull 5125); Direct play sidecars use the same labels.
function getPutioSubtitleLabels(subtitles as object) as object
    labels = []
    counts = CreateObject("roAssociativeArray")
    counts.SetModeCaseSensitive()
    for each subtitle in subtitles
        label = getPutioSubtitleLabel(subtitle)
        count = 1
        if counts.DoesExist(label)
            count = counts[label] + 1
        end if
        counts[label] = count
        if count > 1
            label = label + " (" + count.toStr() + ")"
        end if
        labels.push(label)
    end for

    return labels
end function

function getPutioSubtitleLabel(subtitle as object) as string
    language = "Unknown"
    languageName = subtitle.lookupCI("language")
    languageCode = subtitle.lookupCI("language_code")
    if languageName <> invalid and languageName.toStr() <> "" and (languageCode = invalid or languageCode.toStr() <> "und")
        language = languageName.toStr()
    end if

    name = subtitle.lookupCI("name")
    if name = invalid or name.toStr() = ""
        return language
    end if

    return language + " - " + getCleanSubtitleName(name)
end function

' Drops the final extension like Python's os.path.splitext, which ignores leading dots.
function getCleanSubtitleName(name) as string
    cleanName = name.toStr()
    dotIndex = 0
    position = Instr(1, cleanName, ".")
    while position > 0
        dotIndex = position
        position = Instr(position + 1, cleanName, ".")
    end while

    if dotIndex > 1
        stem = Left(cleanName, dotIndex - 1)
        if stem.replace(".", "") <> ""
            cleanName = stem
        end if
    end if

    return cleanName.replace(Chr(34), "'")
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
