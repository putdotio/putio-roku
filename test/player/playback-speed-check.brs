' Driver for playback-speed-check.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0]

    return formatJson({
        nearest: [
            getNearestPlaybackSpeed(speeds, 2.0),
            getNearestPlaybackSpeed(speeds, 1.02),
            getNearestPlaybackSpeed(speeds, 3.9),
            getNearestPlaybackSpeed(speeds, 1.22),
            getNearestPlaybackSpeed(speeds, 0.52),
            getNearestPlaybackSpeed([0.25, 0.5, 0.75, 1.0], 1.9)
        ],
        kept: [
            getPlaybackSpeedsBefore(speeds, 2.5),
            getPlaybackSpeedsBefore(speeds, 1.25),
            getPlaybackSpeedsBefore(speeds, 0.5)
        ]
    })
end function
