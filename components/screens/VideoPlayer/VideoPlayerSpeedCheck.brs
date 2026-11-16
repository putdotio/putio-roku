' Video.playbackSpeed is undocumented. Some models (3820X, A113X) accept speeds above 2x,
' read them back, and keep playing at the previous rate, so only position progress shows the rate.
sub startPlaybackSpeedCheck(requestedSpeed)
    if requestedSpeed = m.confirmedPlaybackSpeed
        m.playbackSpeedCheck = invalid
        return
    end if

    m.playbackSpeedCheck = {
        requestedSpeed: requestedSpeed,
        startPosition: invalid,
        clock: CreateObject("roTimespan")
    }
end sub

sub checkPlaybackSpeed(position)
    check = m.playbackSpeedCheck
    if check = invalid or position = invalid
        return
    end if

    if m.video.state <> "playing" or m.seekInProgress
        check.startPosition = invalid
        return
    end if

    if check.startPosition = invalid
        check.startPosition = position
        check.clock.mark()
        return
    end if

    elapsedMs = check.clock.totalMilliseconds()
    if elapsedMs < m.playbackSpeedCheckWindowMs
        return
    end if

    observedRate = (position - check.startPosition) * 1000 / elapsedMs
    m.playbackSpeedCheck = invalid

    if isPlaybackSpeedHonoured(check.requestedSpeed, m.confirmedPlaybackSpeed, observedRate)
        m.confirmedPlaybackSpeed = check.requestedSpeed
        return
    end if

    m.playbackSpeedOptions = getPlaybackSpeedsBefore(m.playbackSpeedOptions, check.requestedSpeed)
    m.selectedPlaybackSpeed = m.confirmedPlaybackSpeed
    m.selectedPlaybackSpeedLabel = getPlaybackSpeedLabel(m.confirmedPlaybackSpeed)
    enforcePlaybackSpeed()
end sub

function isPlaybackSpeedHonoured(requestedSpeed, confirmedSpeed, observedRate) as boolean
    midpoint = (requestedSpeed + confirmedSpeed) / 2

    if requestedSpeed > confirmedSpeed
        return observedRate >= midpoint
    end if

    return observedRate <= midpoint
end function

function getPlaybackSpeedsBefore(speeds, rejectedSpeed) as object
    kept = []

    for each speed in speeds
        if rejectedSpeed > 1 and speed < rejectedSpeed
            kept.push(speed)
        else if rejectedSpeed < 1 and speed > rejectedSpeed
            kept.push(speed)
        end if
    end for

    return kept
end function
