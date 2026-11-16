' Video.playbackSpeed is undocumented. Some models (3820X, A113X) accept speeds above 2x,
' read them back, and keep playing at the previous rate, so only position progress shows the rate.
sub startPlaybackSpeedCheck(requestedSpeed)
    m.playbackSpeedCheck = {
        requestedSpeed: requestedSpeed,
        startPosition: invalid,
        clock: CreateObject("roTimespan"),
        sinceLastPosition: CreateObject("roTimespan")
    }
end sub

sub restartPlaybackSpeedCheckWindow()
    if m.playbackSpeedCheck <> invalid
        m.playbackSpeedCheck.startPosition = invalid
    end if
end sub

sub checkPlaybackSpeed(position)
    check = m.playbackSpeedCheck
    if check = invalid or position = invalid
        return
    end if

    positionGapMs = check.sinceLastPosition.totalMilliseconds()
    check.sinceLastPosition.mark()

    if m.video.state <> "playing" or m.seekInProgress or positionGapMs > m.playbackSpeedCheckMaxGapMs
        check.startPosition = invalid
    end if

    if m.video.state <> "playing" or m.seekInProgress
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
    actualSpeed = getNearestPlaybackSpeed(m.playbackSpeedOptions, observedRate)

    if actualSpeed = check.requestedSpeed
        return
    end if

    m.playbackSpeedOptions = getPlaybackSpeedsBefore(m.playbackSpeedOptions, check.requestedSpeed)
    m.selectedPlaybackSpeed = actualSpeed
    m.selectedPlaybackSpeedLabel = getPlaybackSpeedLabel(actualSpeed)
    enforcePlaybackSpeed()

    if m.trackMenu.visible and m.trackMenuMode = "speed"
        closeTrackMenu()
    end if
end sub

function getNearestPlaybackSpeed(speeds, rate) as float
    nearest = 1.0

    for each speed in speeds
        if Abs(speed - rate) < Abs(nearest - rate)
            nearest = speed
        end if
    end for

    return nearest
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
