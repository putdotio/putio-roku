' put.io's HLS manifest lists the /subtitles entries that converted to HLS, grouped by language,
' named "<language>" or "<language> <n>" when a language has several. Roku exposes only that name,
' so a track borrows its /subtitles entry when the language's counts agree, and keeps the name otherwise.
function matchManifestSubtitles(manifestTracks as object, subtitles as object) as object
    sidecarsByLanguage = {}
    if subtitles <> invalid
        for each subtitle in subtitles
            if isManifestSubtitleFormat(subtitle)
                language = getManifestSubtitleLanguage(subtitle)
                if sidecarsByLanguage.doesExist(language) = false
                    sidecarsByLanguage[language] = []
                end if
                sidecarsByLanguage[language].push(subtitle)
            end if
        end for
    end if

    manifestCounts = {}
    parsed = []
    for each track in manifestTracks
        name = parseManifestSubtitleName(track)
        parsed.push(name)
        if name <> invalid
            manifestCounts[name.language] = getManifestCount(manifestCounts, name.language) + 1
        end if
    end for

    matches = []
    for each name in parsed
        match = invalid
        if name <> invalid and sidecarsByLanguage.doesExist(name.language)
            sidecars = sidecarsByLanguage[name.language]
            if sidecars.count() = manifestCounts[name.language] and name.index <= sidecars.count()
                match = sidecars[name.index - 1]
            end if
        end if
        matches.push(match)
    end for

    return matches
end function

function isManifestSubtitleFormat(subtitle) as boolean
    if subtitle = invalid or subtitle.format = invalid
        return false
    end if

    format = LCase(subtitle.format.toStr())
    return format = "srt" or format = "webvtt" or format = "vtt"
end function

function getManifestSubtitleLanguage(subtitle) as string
    if subtitle.language_code = invalid or subtitle.language_code.toStr() = "und" or subtitle.language = invalid or subtitle.language.toStr() = ""
        return "Unknown"
    end if

    return subtitle.language.toStr()
end function

function parseManifestSubtitleName(track) as dynamic
    if track = invalid or track.Description = invalid or track.Description.toStr() = ""
        return invalid
    end if

    description = track.Description.toStr()
    spaceIndex = 0
    position = Instr(1, description, " ")
    while position > 0
        spaceIndex = position
        position = Instr(position + 1, description, " ")
    end while

    if spaceIndex > 0
        suffix = Mid(description, spaceIndex + 1)
        if isManifestSubtitleIndex(suffix)
            return { language: Left(description, spaceIndex - 1), index: suffix.toInt() }
        end if
    end if

    return { language: description, index: 1 }
end function

function isManifestSubtitleIndex(value as string) as boolean
    if value = "" or Len(value) > 3
        return false
    end if

    for i = 1 to Len(value)
        code = Asc(Mid(value, i, 1))
        if code < 48 or code > 57
            return false
        end if
    end for

    return value.toInt() > 0
end function

function getManifestCount(counts as object, language as string) as integer
    if counts.doesExist(language)
        return counts[language]
    end if

    return 0
end function

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
