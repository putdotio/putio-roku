function isNonEmptyString(value) as boolean
    return value <> invalid and value.toStr() <> ""
end function

function getHlsManifestUrl(file as object, apiUrl, downloadToken) as string
    normalizedApiUrl = apiUrl.toStr()
    if Right(normalizedApiUrl, 1) = "/"
        normalizedApiUrl = Left(normalizedApiUrl, Len(normalizedApiUrl) - 1)
    end if

    return normalizedApiUrl + "/files/" + file.id.toStr() + "/hls/media.m3u8?oauth_token=" + downloadToken.toStr()
end function

function getVideoFileDurationSeconds(file as object) as integer
    if file <> invalid and file.video_metadata <> invalid and file.video_metadata.duration <> invalid
        return file.video_metadata.duration
    end if

    return 0
end function

function isPlaybackFinishedAt(position, duration) as boolean
    return duration <> invalid and duration > 0 and position <> invalid and position >= int(duration * 0.95)
end function
