function getDefaultPlaybackMethod() as string
    return "hls"
end function

function normalizePlaybackMethod(method as dynamic) as string
    if method <> invalid and LCase(method.toStr()) = "file"
        return "file"
    end if

    return getDefaultPlaybackMethod()
end function

function getOtherPlaybackMethod(method as dynamic) as string
    if normalizePlaybackMethod(method) = "file"
        return "hls"
    end if

    return "file"
end function

function getPlaybackMethodLabel(method as dynamic) as string
    if normalizePlaybackMethod(method) = "file"
        return "Direct play"
    end if

    return "Standard"
end function

function getPlaybackMethodFromConfig(config as dynamic) as string
    if config <> invalid and config.doesExist("streaming_method")
        return normalizePlaybackMethod(config.streaming_method)
    end if

    return getDefaultPlaybackMethod()
end function

function getPlaybackMethodHint(method as dynamic) as string
    if normalizePlaybackMethod(method) = "file"
        return "Plays the original file, up to 4K and surround, when this device can. Converted otherwise."
    end if

    return "Works on every device. Converted videos play at up to 1080p, stereo."
end function
