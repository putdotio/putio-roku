function getUniqueSubtitleLabels(baseLabels as object) as object
    reserved = CreateObject("roAssociativeArray")
    reserved.SetModeCaseSensitive()
    for each label in baseLabels
        reserved[label] = true
    end for

    labels = []
    used = CreateObject("roAssociativeArray")
    used.SetModeCaseSensitive()
    for each label in baseLabels
        candidate = label
        if used.DoesExist(candidate)
            count = 2
            candidate = label + " (" + count.toStr() + ")"
            while reserved.DoesExist(candidate) or used.DoesExist(candidate)
                count += 1
                candidate = label + " (" + count.toStr() + ")"
            end while
        end if
        used[candidate] = true
        labels.push(candidate)
    end for

    return labels
end function

function getPutioSubtitleLanguage(subtitle as object) as string
    language = "Unknown"
    languageName = subtitle.lookupCI("language")
    languageCode = subtitle.lookupCI("language_code")
    if languageCode = invalid then languageCode = ""
    if LCase(languageCode.toStr()) <> "und"
        if languageName <> invalid and languageName.toStr() <> "" and LCase(languageName.toStr()) <> "undetermined"
            language = languageName.toStr()
        else if languageCode <> ""
            language = languageCode.toStr()
        end if
    end if

    return language
end function

function getPutioSubtitleLabel(subtitle as object, language as string) as string
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
