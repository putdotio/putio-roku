function resolvePlaybackPlan(file as object, method as dynamic, ctx as object) as object
    if file = invalid or ctx = invalid
        return createUnplayablePlan("not_ready")
    end if

    if file.file_type = "AUDIO"
        return resolveAudioPlaybackPlan(file, ctx)
    end if

    if normalizePlaybackMethod(method) = "file"
        return resolveDirectPlayPlan(file, ctx)
    end if

    return resolveStandardPlaybackPlan(file, ctx)
end function

function normalizePlaybackMethod(method as dynamic) as string
    if method <> invalid and LCase(method.toStr()) = "file"
        return "file"
    end if

    return "hls"
end function

function resolveAudioPlaybackPlan(file as object, ctx as object) as object
    if hasPlaybackApiAccess(file, ctx) = false
        return createUnplayablePlan("not_ready")
    end if

    url = trimTrailingSlash(ctx.apiUrl.toStr()) + "/files/" + file.id.toStr() + "/stream.mp3?oauth_token=" + ctx.downloadToken.toStr()
    return createPlaybackPlan("play", "original", url, invalid, invalid)
end function

function resolveStandardPlaybackPlan(file as object, ctx as object) as object
    if file.need_convert <> false and file.is_mp4_available <> true
        return createPlaybackPlan("convert", "hls", invalid, invalid, invalid)
    end if

    if hasPlaybackApiAccess(file, ctx) = false
        return createUnplayablePlan("not_ready")
    end if

    return createPlaybackPlan("play", "hls", getHlsManifestUrl(file, ctx.apiUrl, ctx.downloadToken), "hls", invalid)
end function

function resolveDirectPlayPlan(file as object, ctx as object) as object
    if ctx.originalFailed = true
        reason = "decoder_error"
        if isNonEmptyString(ctx.failureReason)
            reason = ctx.failureReason.toStr()
        end if

        return resolveDirectPlayFallbackPlan(file, reason)
    end if

    check = checkDirectPlay(file.media_info, ctx.probe)
    if check.ok <> true
        return resolveDirectPlayFallbackPlan(file, check.reason)
    end if

    if isNonEmptyString(file.stream_url) = false
        return resolveDirectPlayFallbackPlan(file, "not_ready")
    end if

    return createPlaybackPlan("play", "original", file.stream_url.toStr(), check.streamFormat, invalid)
end function

function resolveDirectPlayFallbackPlan(file as object, reason as string) as object
    if file.is_mp4_available = true and isNonEmptyString(file.mp4_stream_url)
        return createPlaybackPlan("play", "converted", file.mp4_stream_url.toStr(), "mp4", reason)
    end if

    if file.need_convert <> false
        return createPlaybackPlan("convert", "converted", invalid, invalid, reason)
    end if

    return createUnplayablePlan(reason)
end function

function hasPlaybackApiAccess(file as object, ctx as object) as boolean
    return file.id <> invalid and isNonEmptyString(ctx.apiUrl) and isNonEmptyString(ctx.downloadToken)
end function

function trimTrailingSlash(url as string) as string
    if Right(url, 1) = "/"
        return Left(url, Len(url) - 1)
    end if

    return url
end function

function createUnplayablePlan(reason as string) as object
    return createPlaybackPlan("unplayable", invalid, invalid, invalid, reason)
end function

function createPlaybackPlan(action as string, source as dynamic, url as dynamic, streamFormat as dynamic, reason as dynamic) as object
    return {
        action: action,
        source: source,
        url: url,
        streamFormat: streamFormat,
        reason: reason
    }
end function
