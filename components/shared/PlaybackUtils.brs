function isNonEmptyString(value) as boolean
    return value <> invalid and value.toStr() <> ""
end function

function isPlaybackConversionReady(file as object) as boolean
    return file <> invalid and file.need_convert <> true
end function

function hasPlayableMp4Stream(file as object) as boolean
    return isPlaybackConversionReady(file) and file.is_mp4_available = true and isNonEmptyString(file.mp4_stream_url)
end function

function hasPlayableStreamUrl(file as object) as boolean
    return isPlaybackConversionReady(file) and isNonEmptyString(file.stream_url)
end function

function hasPlayableHlsStream(file as object) as boolean
    return isPlaybackConversionReady(file) and file.id <> invalid
end function

function hasPlayableVideoStream(file as object) as boolean
    return hasPlayableMp4Stream(file) or hasPlayableHlsStream(file) or hasPlayableStreamUrl(file)
end function

function getPlayableStreamInfo(file as object, apiUrl, downloadToken, playbackType = "hls") as object
    if getNormalizedPlaybackType(playbackType) = "mp4"
        return getMp4FirstStreamInfo(file, apiUrl, downloadToken)
    end if

    return getHlsFirstStreamInfo(file, apiUrl, downloadToken)
end function

function getHlsFirstStreamInfo(file as object, apiUrl, downloadToken) as object
    hlsStreamInfo = getHlsStreamInfo(file, apiUrl, downloadToken)
    if hlsStreamInfo <> invalid
        return hlsStreamInfo
    end if

    return getMp4StreamInfo(file)
end function

function getMp4FirstStreamInfo(file as object, apiUrl, downloadToken) as object
    mp4StreamInfo = getMp4StreamInfo(file)
    if mp4StreamInfo <> invalid
        return mp4StreamInfo
    end if

    return getHlsStreamInfo(file, apiUrl, downloadToken)
end function

function getHlsStreamInfo(file as object, apiUrl, downloadToken) as object
    if hasPlayableHlsStream(file) = false or isNonEmptyString(apiUrl) = false or isNonEmptyString(downloadToken) = false
        return invalid
    end if

    return {
        url: getHlsManifestUrl(file, apiUrl, downloadToken),
        format: "hls"
    }
end function

function getMp4StreamInfo(file as object) as object
    if hasPlayableMp4Stream(file)
        return {
            url: file.mp4_stream_url.toStr(),
            format: "mp4"
        }
    end if

    if hasPlayableStreamUrl(file)
        streamUrl = file.stream_url.toStr()
        return {
            url: streamUrl,
            format: getPlaybackStreamFormat(streamUrl)
        }
    end if

    return invalid
end function

function getNormalizedPlaybackType(playbackType) as string
    return normalizePlaybackTypeSetting(playbackType)
end function

function getHlsManifestUrl(file as object, apiUrl, downloadToken) as string
    normalizedApiUrl = apiUrl.toStr()
    if Right(normalizedApiUrl, 1) = "/"
        normalizedApiUrl = Left(normalizedApiUrl, Len(normalizedApiUrl) - 1)
    end if

    return normalizedApiUrl + "/files/" + file.id.toStr() + "/hls/media.m3u8?oauth_token=" + downloadToken.toStr()
end function

function getPlaybackStreamFormat(streamUrl as string) as string
    lowerUrl = LCase(streamUrl)

    if Instr(1, lowerUrl, ".m3u8") > 0 or Instr(1, lowerUrl, "/hls/") > 0
        return "hls"
    end if

    if Instr(1, lowerUrl, ".mp4") > 0 or Instr(1, lowerUrl, "/stream/") > 0
        return "mp4"
    end if

    ' put.io stream_url is a direct stream fallback unless the URL identifies HLS.
    return "mp4"
end function

function getVideoFileDurationSeconds(file as object) as integer
    if file <> invalid and file.video_metadata <> invalid and file.video_metadata.duration <> invalid
        return file.video_metadata.duration
    end if

    return 0
end function
