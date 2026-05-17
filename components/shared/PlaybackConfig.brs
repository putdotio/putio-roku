function getDefaultPlaybackType() as string
    return "hls"
end function

function getPlaybackTypeLabel(playbackType) as string
    if normalizePlaybackTypeSetting(playbackType) = "mp4"
        return "MP4"
    end if

    return "HLS"
end function

function normalizePlaybackTypeSetting(playbackType) as string
    if playbackType <> invalid and LCase(playbackType.toStr()) = "mp4"
        return "mp4"
    end if

    return getDefaultPlaybackType()
end function

function getPlaybackTypeFromConfig(config) as string
    playbackType = invalid

    if config <> invalid
        playbackType = readPlaybackTypeConfigValue(config, "playbackType")
        if playbackType = invalid
            playbackType = readPlaybackTypeConfigValue(config, "videoPlaybackType")
        end if
        if playbackType = invalid
            playbackType = readPlaybackTypeConfigValue(config, "video_playback_type")
        end if
    end if

    return normalizePlaybackTypeSetting(playbackType)
end function

function readPlaybackTypeConfigValue(config, key)
    if config <> invalid and config.doesExist(key)
        return config[key]
    end if

    return invalid
end function
