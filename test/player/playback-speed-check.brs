' Driver for playback-speed-check.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0]

    return formatJson({
        honoured: [
            isPlaybackSpeedHonoured(3.0, 2.0, 2.0),
            isPlaybackSpeedHonoured(1.25, 1.0, 1.0),
            isPlaybackSpeedHonoured(4.0, 1.0, 3.9),
            isPlaybackSpeedHonoured(1.25, 1.0, 1.22),
            isPlaybackSpeedHonoured(0.5, 1.0, 0.52),
            isPlaybackSpeedHonoured(0.5, 1.0, 1.0)
        ],
        kept: [
            getPlaybackSpeedsBefore(speeds, 2.5),
            getPlaybackSpeedsBefore(speeds, 1.25),
            getPlaybackSpeedsBefore(speeds, 0.5)
        ]
    })
end function
