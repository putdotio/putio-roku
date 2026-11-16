function checkDirectPlay(mediaInfo as object, probe as object) as object
    if mediaInfo = invalid or mediaInfo.streams = invalid or mediaInfo.streams.count() = 0
        return createDirectPlayVerdict("not_ready", invalid)
    end if

    if mediaInfo.playback_issues <> invalid and mediaInfo.playback_issues.count() > 0
        return createDirectPlayVerdict("playback_issue", invalid)
    end if

    container = getDirectPlayContainer(mediaInfo)
    if container = invalid
        return createDirectPlayVerdict("container_unsupported", invalid)
    end if

    if isDirectPlayVideoDecodable(mediaInfo, container, probe) = false
        return createDirectPlayVerdict("video_unsupported", invalid)
    end if

    audioReason = getDirectPlayAudioReason(mediaInfo, container, probe)
    if audioReason <> invalid
        return createDirectPlayVerdict(audioReason, invalid)
    end if

    return createDirectPlayVerdict(invalid, container)
end function

function createDirectPlayVerdict(reason as dynamic, streamFormat as dynamic) as object
    return {
        ok: reason = invalid,
        reason: reason,
        streamFormat: streamFormat
    }
end function

function getDirectPlayContainer(mediaInfo as object) as dynamic
    mimeType = lowerDirectPlayField(mediaInfo, "mime_type")
    ' The backend reports WebM as format.name "matroska"; only mime_type tells them apart.
    if mimeType = "video/webm" or mimeType = "audio/webm"
        return invalid
    end if

    ' format.name can be a raw ffprobe list such as "mov,mp4,m4a,3gp,3g2,mj2" or "matroska,webm".
    for each formatName in lowerDirectPlayField(mediaInfo.format, "name").split(",")
        formatName = formatName.trim()
        if formatName = "mp4" or formatName = "mov" or formatName = "m4v"
            return "mp4"
        else if formatName = "matroska"
            return "mkv"
        end if
    end for

    return invalid
end function

function isDirectPlayVideoDecodable(mediaInfo as object, container as string, probe as object) as boolean
    stream = getDirectPlayVideoStream(mediaInfo.streams)
    if stream = invalid
        return false
    end if

    codecName = lowerDirectPlayField(stream, "codec_name")
    profileName = lowerDirectPlayField(stream, "profile")
    if codecName = "h264"
        rokuCodec = "mpeg4 avc"
        profile = getDirectPlayAvcProfile(profileName)
        level = getDirectPlayAvcLevel(stream.level)
        bitRateCap = getDirectPlayAvcBitRateCap()
    else if codecName = "hevc"
        rokuCodec = "hevc"
        profile = getDirectPlayHevcProfile(profileName)
        level = getDirectPlayHevcLevel(stream.level)
        bitRateCap = getDirectPlayHevcBitRateCap()
    else
        return false
    end if

    if profile = invalid
        return false
    end if

    if needsUltraHdVideoMode(stream) and isUltraHdOutputActive(probe) = false
        return false
    end if

    if profile = "main 10" and probe.hdr10() <> true
        return false
    end if

    rfc6381Codec = lowerDirectPlayField(stream, "rfc6381_codec")
    if Left(rfc6381Codec, 4) = "dvh1" or Left(rfc6381Codec, 4) = "dvhe"
        return false
    end if

    bitRate = getDirectPlayNumber(mediaInfo.format, "bit_rate")
    if bitRate <> invalid and bitRate > bitRateCap * getDirectPlayPeakBitRateFactor()
        return false
    end if

    ' Keys must be lowercase and quoted: CanDecodeVideo matches them case-sensitively before OS 14.1.
    return probe.canDecodeVideo({ "codec": rokuCodec, "profile": profile, "level": level, "container": container }) = true
end function

function getDirectPlayAudioReason(mediaInfo as object, container as string, probe as object) as dynamic
    stream = getDirectPlayStream(mediaInfo.streams, "audio")
    if stream = invalid
        return invalid
    end if

    rokuCodec = getDirectPlayAudioCodec(lowerDirectPlayField(stream, "codec_name"))
    if rokuCodec = invalid
        return "audio_unsupported"
    end if

    channels = getDirectPlayNumber(stream, "channels")
    if channels = invalid or channels < 1
        channels = getDirectPlayHardestChannelCount()
    end if

    ' Keys must be lowercase and quoted: CanDecodeAudio matches them case-sensitively before OS 14.1.
    ' PassThru is left out so the device answers for decode or passthrough.
    if probe.canDecodeAudio({ "codec": rokuCodec, "chcnt": Int(channels), "container": container }) = true
        return invalid
    end if

    return "audio_unsupported"
end function

function getDirectPlayVideoStream(streams as object) as object
    for each stream in streams
        if stream <> invalid and lowerDirectPlayField(stream, "codec_type") = "video" and isDirectPlayCoverArt(stream) = false
            return stream
        end if
    end for

    return invalid
end function

function isDirectPlayCoverArt(stream as object) as boolean
    codecName = lowerDirectPlayField(stream, "codec_name")
    return codecName = "mjpeg" or codecName = "png" or codecName = "bmp" or codecName = "gif" or codecName = "webp"
end function

function getDirectPlayStream(streams as object, codecType as string) as object
    for each stream in streams
        if stream <> invalid and lowerDirectPlayField(stream, "codec_type") = codecType
            return stream
        end if
    end for

    return invalid
end function

function getDirectPlayAvcProfile(profileName as string) as dynamic
    if profileName = "high"
        return "high"
    else if profileName = "main" or profileName = "constrained baseline" or profileName = "baseline"
        return "main"
    end if

    return invalid
end function

function getDirectPlayHevcProfile(profileName as string) as dynamic
    if profileName = "main"
        return "main"
    else if profileName = "main 10"
        return "main 10"
    end if

    return invalid
end function

' ffprobe reports H.264 level_idc, ten times the level: 41 is level 4.1.
function getDirectPlayAvcLevel(rawLevel as dynamic) as string
    levelTenths = getDirectPlayPositiveNumber(rawLevel)
    if levelTenths = invalid
        return getDirectPlayHardestLevel()
    end if

    return formatDirectPlayLevel(Int(levelTenths))
end function

' ffprobe reports HEVC general_level_idc, thirty times the level: 153 is level 5.1.
function getDirectPlayHevcLevel(rawLevel as dynamic) as string
    levelIdc = getDirectPlayPositiveNumber(rawLevel)
    if levelIdc = invalid or Int(levelIdc) mod getDirectPlayHevcLevelIdcPerTenth() <> 0
        return getDirectPlayHardestLevel()
    end if

    return formatDirectPlayLevel(Int(levelIdc) \ getDirectPlayHevcLevelIdcPerTenth())
end function

' CanDecodeVideo documents no level below 4.1, and a decoder for a level also plays every lower one.
function formatDirectPlayLevel(levelTenths as integer) as string
    if levelTenths < getDirectPlayLowestDocumentedLevelTenths()
        levelTenths = getDirectPlayLowestDocumentedLevelTenths()
    end if

    return (levelTenths \ 10).toStr() + "." + (levelTenths mod 10).toStr()
end function

function needsUltraHdVideoMode(stream as object) as boolean
    width = getDirectPlayPositiveNumber(stream.width)
    height = getDirectPlayPositiveNumber(stream.height)
    if width = invalid or height = invalid
        return false
    end if

    longSide = width
    if height > longSide
        longSide = height
    end if

    return longSide > getDirectPlayFullHdLongSide()
end function

' Roku's 4K check: video mode 2160p or higher, and HDCP 2.2 on streaming players.
function isUltraHdOutputActive(probe as object) as boolean
    if getVideoModeLines(probe.videoMode()) < getDirectPlayUltraHdLines()
        return false
    end if

    return probe.isStb() <> true or probe.hdcp22Active() = true
end function

function getVideoModeLines(videoMode as dynamic) as integer
    if videoMode = invalid
        return 0
    end if

    text = videoMode.toStr()
    lines = 0
    for index = 1 to Len(text)
        digit = Asc(Mid(text, index, 1)) - Asc("0")
        if digit < 0 or digit > 9
            exit for
        end if
        lines = lines * 10 + digit
    end for

    return lines
end function

function getDirectPlayAudioCodec(codecName as string) as dynamic
    codecs = {
        "aac": "aac",
        "ac3": "ac3",
        "eac3": "eac3",
        "ac4": "ac4",
        "alac": "alac",
        "flac": "flac",
        "mp2": "mp2",
        "mp3": "mp3",
        "vorbis": "vorbis",
        "dts": "dts"
    }
    if codecName <> "" and codecs.doesExist(codecName)
        return codecs[codecName]
    end if

    return invalid
end function

function getDirectPlayPositiveNumber(value as dynamic) as dynamic
    number = toDirectPlayNumber(value)
    if number = invalid or number <= 0
        return invalid
    end if

    return number
end function

function getDirectPlayNumber(source as object, key as string) as dynamic
    if source = invalid
        return invalid
    end if

    return toDirectPlayNumber(source[key])
end function

function toDirectPlayNumber(value as dynamic) as dynamic
    if value = invalid
        return invalid
    end if

    if GetInterface(value, "ifString") <> invalid
        if value.trim() = ""
            return invalid
        end if

        return Val(value, 10)
    end if

    ' type() names differ by source on devices (roInt, roInteger, roIntrinsicDouble), so match interfaces.
    if GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifLongInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid
        return value
    end if

    return invalid
end function

function lowerDirectPlayField(source as object, key as string) as string
    if source = invalid or source[key] = invalid
        return ""
    end if

    return LCase(source[key].toStr().trim())
end function

function getDirectPlayHardestLevel() as string
    return "6.2"
end function

function getDirectPlayHardestChannelCount() as integer
    return 8
end function

function getDirectPlayLowestDocumentedLevelTenths() as integer
    return 41
end function

function getDirectPlayHevcLevelIdcPerTenth() as integer
    return 3
end function

function getDirectPlayFullHdLongSide() as integer
    return 1920
end function

function getDirectPlayUltraHdLines() as integer
    return 2160
end function

function getDirectPlayAvcBitRateCap() as double
    return 10000000#
end function

function getDirectPlayHevcBitRateCap() as double
    return 40000000#
end function

function getDirectPlayPeakBitRateFactor() as float
    return 1.5
end function
